.pragma library

// Tunable visual modes, not measured material constants: sway X/Z, squash,
// twist, two ears and delayed upper-body sway X/Z.
var stiffness = [225, 196, 400, 256, 625, 676, 324, 289];
var damping = [7.5, 7, 8, 8, 12, 12, 13, 12];
var limits = [0.38, 0.33, 0.34, 0.32, 0.26, 0.26, 0.42, 0.37];

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function create() { return { q: limits.map(function() { return 0; }), v: limits.map(function() { return 0; }) }; }

function pose(state) {
    // Saturate the visible displacement smoothly, preserving spring momentum.
    return state.q.map(function(q, i) {
        var limit = i === 2 && q < 0 ? 0.20 : limits[i];
        return limit * Math.tanh(q / limit);
    });
}

function excite(state, x, z, squash, twist) {
    if (![x, z, squash, twist].every(Number.isFinite)) return;
    // Hit the main mass; the upper body and ears follow through their springs.
    var impulse = [x, z, squash, twist];
    for (var i = 0; i < 4; i++) state.v[i] = clamp(state.v[i] + impulse[i], -10, 10);
}

function poke(state, x, y, yaw) {
    if (![x, y, yaw].every(Number.isFinite)) return;
    var side = clamp(x * 2 - 1, -1, 1);
    var height = clamp(1 - y, 0, 1);
    var lateral = -side * (2.0 + height * 2.2);
    var depth = (0.3 - height) * 2.8;
    excite(state, lateral * Math.cos(yaw) + depth * Math.sin(yaw),
           -lateral * Math.sin(yaw) + depth * Math.cos(yaw),
           3.0 + (1 - height) * 1.6, side * (height - 0.5) * 2.2);
}

function dance(state, levels, previous, phase) {
    if (!Number.isFinite(phase) || !Array.isArray(levels) || levels.length !== 24
            || !levels.every(function(v) { return Number.isFinite(v) && v >= 0 && v <= 1; })) return false;
    var history = Array.isArray(previous) && previous.length === 24 ? previous : [];
    var flux = 0, peakRise = 0;
    // Per-band rises catch drums, vocals and cymbals even when total loudness
    // stays constant. Use raw spectrum frames, not the smoothed bass envelope.
    for (var i = 0; i < levels.length; i++) {
        var current = Math.max(0, levels[i] - 0.03);
        var before = Math.max(0, (history[i] || 0) - 0.03);
        var rise = Math.max(0, current - before);
        flux += rise;
        peakRise = Math.max(peakRise, rise);
    }
    var strength = clamp(flux / levels.length * 8 + peakRise * 0.6, 0, 1);
    if (strength <= 0) return false;
    // Two perpendicular components avoid a dead spot when one sine is zero.
    var side = Math.cos(phase * 2);
    var depth = Math.sin(phase * 2);
    excite(state, side * strength * 4, depth * strength * 3,
           strength * 1.6, side * strength * 0.6);
    return true;
}

function advance(state, seconds, squeeze, held) {
    if (!Number.isFinite(seconds) || seconds <= 0) return true;
    // Discard suspend/stall time; substeps keep rapid repeated pokes bounded.
    var dt = Math.min(seconds, 0.05);
    var steps = Math.ceil(dt / 0.004);
    var h = dt / steps;
    var target = held && Number.isFinite(squeeze) ? clamp(squeeze, -0.16, 0.28) : 0;
    var limit = target < 0 ? 0.20 : limits[2];
    var heldSquash = limit * Math.atanh(target / limit);
    for (var step = 0; step < steps; step++) {
        var targets = [0, 0, heldSquash, 0,
                       state.q[6] * 0.45 + state.q[7] * 0.30 + state.q[3] * 0.55 - state.q[2] * 0.25,
                       state.q[6] * 0.45 + state.q[7] * 0.30 - state.q[3] * 0.55 + state.q[2] * 0.25,
                       state.q[0], state.q[1] - state.q[2] * 0.45];
        for (var i = 0; i < limits.length; i++) {
            var drag = held && i === 2 ? 28 : damping[i];
            state.v[i] += (stiffness[i] * (targets[i] - state.q[i]) - drag * state.v[i]) * h;
            state.q[i] += state.v[i] * h;
        }
    }
    var active = false;
    for (var j = 0; j < limits.length; j++)
        active = active || Math.abs(state.q[j]) > 0.0005 || Math.abs(state.v[j]) > 0.008;
    if (!active) {
        for (var k = 0; k < limits.length; k++) state.q[k] = state.v[k] = 0;
    }
    return active;
}

// One offline check covers accumulation, release, stalls and eventual sleep.
function selfCheck() {
    function check(ok, message) { if (!ok) throw new Error(message); }
    var silence = Array(24).fill(0);
    check(!dance(create(), silence, silence, 0), "Silence must not add impulses");
    for (var band of [2, 12, 22]) {
        var music = create(), spectrum = silence.slice();
        spectrum[band] = 0.6;
        check(dance(music, spectrum, silence, 0) && music.v[0] > 0 && music.v[2] > 0, "Low, middle and high frequencies must all excite the gel");
        var velocity = music.v.slice();
        check(!dance(music, spectrum, spectrum, 1) && !dance(music, silence, spectrum, 1)
              && music.v.every(function(v, i) { return v === velocity[i]; }), "Steady and falling levels must not add impulses");
    }
    var lowBand = silence.slice(), highBand = silence.slice();
    lowBand[2] = highBand[22] = 0.6;
    check(dance(create(), highBand, lowBand, 0), "Frequency changes at constant loudness must remain audible to the motion");
    var boundary = create();
    boundary.q[0] = limits[0] + 0.02;
    boundary.v[0] = 1;
    advance(boundary, 0.001, 0, false);
    check(boundary.v[0] > 0 && pose(boundary)[0] < limits[0], "Soft bounds must not reflect spring velocity");
    var left = create(), right = create(), low = create(), rotated = create();
    poke(left, 0.25, 0.25, 0);
    poke(right, 0.75, 0.25, 0);
    poke(low, 0.25, 0.8, 0);
    poke(rotated, 0.25, 0.25, Math.PI);
    check(left.v[0] > 0 && right.v[0] < 0, "Pokes must bend away from their side");
    check(low.v[2] > left.v[2] && low.v[3] * left.v[3] < 0, "Poke height must change compression and twist");
    check(Math.abs(left.v[0] + rotated.v[0]) < 1e-8, "Pokes must follow the current view");
    var state = create();
    excite(state, 1, 0, 0, 0);
    excite(state, 1, 0, 0, 0);
    check(state.v[0] === 2, "A second poke must add to the current velocity");
    excite(state, -1, 0, 0, 0);
    check(state.v[0] === 1, "An opposing poke must slow the existing movement");
    advance(state, 1 / 120, 0, false);
    check(state.q[6] < state.q[0], "The upper body must lag the main mass");
    for (var i = 0; i < 240; i++) {
        excite(state, 3, -2, 2, 1);
        advance(state, i === 50 ? 10 : 1 / 120, 0.25, true);
        check(pose(state).every(function(q, j) { return Number.isFinite(q) && Math.abs(q) <= limits[j]; }), "Unbounded deformation");
    }
    var crossed = false;
    for (var frame = 0; frame < 1200; frame++) {
        advance(state, 1 / 120, 0, false);
        crossed = crossed || state.q[0] < 0;
    }
    check(crossed, "Release must oscillate through the rest pose");
    check(state.q.every(function(q) { return q === 0; }) && state.v.every(function(v) { return v === 0; }), "Motion must settle and stop requesting frames");
    var squeezed = create();
    for (var tick = 0; tick < 240; tick++) advance(squeezed, 1 / 120, 0.25, true);
    check(Math.abs(pose(squeezed)[2] - 0.25) < 0.005, "Holding must reach the requested compression");
    var rebounded = false;
    var earsMoved = false;
    for (var t = 0; t < 360; t++) {
        advance(squeezed, 1 / 120, 0, false);
        rebounded = rebounded || squeezed.q[2] < -0.04;
        earsMoved = earsMoved || Math.abs(squeezed.q[4]) + Math.abs(squeezed.q[5]) > 0.04;
    }
    check(rebounded && earsMoved, "Compression must rebound and excite the ears");
    var tap = create(), peak = 0, recoil = false;
    poke(tap, 0.5, 0.5, 0);
    for (var tick = 0; tick < 180; tick++) {
        advance(tap, 1 / 120, 0, false);
        peak = Math.max(peak, pose(tap)[2]);
        recoil = recoil || pose(tap)[2] < -0.02;
    }
    check(peak > 0.10 && recoil, "Even an immediately released tap must squash and rebound");
    check(pose(tap).every(function(q) { return Math.abs(q) < 0.015; }), "A tap must visibly settle quickly");
    return "Neko motion: additive taps, soft bounds, hold/release, delayed upper body and settling OK";
}
