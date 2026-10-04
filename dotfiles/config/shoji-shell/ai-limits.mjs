// Provider protocols adapted from howdeploy/CanvasTTY, LimitsService.ts.
// MIT License — Copyright (c) 2026 howdeploy
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import { homedir } from 'node:os';
import { join } from 'node:path';

const MAX_BYTES = 2 * 1024 * 1024;
if (!process.argv.includes('--self-check') && process.env.SHOJI_ENABLE_LIMITS !== '1') {
    console.error('AI limits integration is disabled; opt in locally first');
    process.exit(1);
}
const children = new Set();
const record = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const number = v => (typeof v === 'number' || typeof v === 'string' && v.trim() !== '') && Number.isFinite(Number(v)) ? Number(v) : null;
const fail = (state = 'unavailable') => { throw new Error(state); };
const timestamp = v => {
    const result = typeof v === 'string' ? Date.parse(v) : typeof v === 'number' ? v * (v < 1e12 ? 1000 : 1) : NaN;
    return Number.isFinite(result) && result > 0 && result < 8.64e15 ? result : null;
};
const period = minutes => minutes > 0
    ? minutes % 1440 === 0 ? `${minutes / 1440} дн` : minutes % 60 === 0 ? `${minutes / 60} ч` : `${minutes} мин`
    : 'Текущий период';
function windowData(used, minutes, reset, label = period(minutes)) {
    const percent = number(used);
    return { label, minutes, remaining: percent === null ? null : 100 - Math.min(100, Math.max(0, percent)), resetsAt: timestamp(reset) };
}

function normalize(provider, raw) {
    if (!record(raw)) fail();
    if (provider === 'codex') {
        // Only the default Codex bucket; Spark/model-specific quotas are separate.
        const bucket = raw.rateLimits ?? raw.rateLimitsByLimitId?.codex;
        if (!record(bucket)) return [];
        return ['primary', 'secondary'].flatMap(slot => {
            const w = bucket[slot];
            return record(w) && (number(w.usedPercent) !== null || timestamp(w.resetsAt) !== null)
                ? [windowData(w.usedPercent, number(w.windowDurationMins), w.resetsAt)] : [];
        });
    }
    if (provider === 'grok') {
        const config = record(raw.config) ? raw.config : raw;
        const p = config.currentPeriod ?? {};
        const end = p.end ?? config.billingPeriodEnd;
        const start = timestamp(p.start ?? config.billingPeriodStart);
        const finish = timestamp(end);
        if (number(config.creditUsagePercent) === null && finish === null) return [];
        return [windowData(config.creditUsagePercent, start && finish > start ? Math.round((finish - start) / 60000) : null, end)];
    }
    const payload = record(raw.data) ? raw.data : raw;
    if (payload.kind === 'error') fail([401, 403].includes(payload.status) || /auth|login/i.test(payload.message ?? '') ? 'auth' : 'unavailable');
    if (payload.kind === 'ok' && record(payload.quota?.usages)) {
        return [['limit5h', 300, '5 ч'], ['limit7d', 10080, '7 дн'], ['monthTotal', null, 'Месяц'], ['monthCode', null, 'Код · месяц']]
            .flatMap(([key, duration, label]) => {
                const quota = payload.quota.usages[key];
                if (!record(quota)) return [];
                const ratio = number(quota.usedRatio);
                return [windowData(ratio === null ? null : ratio * 100, duration, quota.resetAt, label)];
            });
    }
    const windows = [];
    function add(detail, minutes) {
        if (!record(detail) || !(minutes > 0)) return;
        const limit = number(detail.limit);
        const remaining = number(detail.remaining);
        const used = number(detail.used) ?? (limit !== null && remaining !== null ? Math.max(0, limit - remaining) : null);
        const reset = detail.resetTime ?? detail.reset_at;
        if (used === null && timestamp(reset) === null) return;
        windows.push(windowData(limit > 0 && used !== null ? used / limit * 100 : null, minutes, reset));
    }
    function minutes(w) {
        if (!record(w)) return null;
        const unit = String(w.timeUnit ?? w.unit).replace(/^TIME_UNIT_/, '').toLowerCase();
        return number(w.duration) * ({ minute: 1, hour: 60, day: 1440, week: 10080 }[unit] ?? 0);
    }
    add(payload.summary, minutes(payload.summary?.window));
    add(payload.usage, 10080);
    for (const w of Array.isArray(payload.limits) ? payload.limits.slice(0, 12) : []) {
        if (record(w)) add(record(w.detail) ? w.detail : w, minutes(w.window));
    }
    return windows.filter((w, i) => windows.findIndex(other => other.minutes === w.minutes && other.resetsAt === w.resetsAt) === i)
        .sort((a, b) => a.minutes - b.minutes).slice(0, 12);
}

function resetCredits(raw) {
    const count = number(raw?.rateLimitResetCredits?.availableCount);
    return Number.isSafeInteger(count) && count >= 0 ? count : null;
}

function stop(child) {
    if (!children.delete(child)) return;
    const kill = signal => { try { process.kill(-child.pid, signal); } catch {} };
    kill('SIGTERM');
    setTimeout(() => kill('SIGKILL'), 500);
}
function launch(command, args) {
    const home = homedir();
    const child = spawn(command, args, {
        detached: true, stdio: ['pipe', 'pipe', 'ignore'], cwd: home,
        env: { ...process.env, PATH: [join(home, '.kimi-code/bin'), join(home, '.npm-global/bin'), join(home, '.local/bin'), process.env.PATH].join(':') }
    });
    children.add(child);
    child.stdin.on('error', () => {});
    // Keep an error listener after startup so a failed child never crashes the collector.
    child.on('error', () => {});
    return child;
}
function outputUntil(child, consume) {
    return new Promise((resolve, reject) => {
        let buffer = '';
        const finish = (error, value) => {
            clearTimeout(timer);
            child.stdout.off('data', data);
            child.off('error', errorHandler);
            child.off('close', closed);
            child.stdout.resume();
            if (error) reject(error); else resolve(value);
        };
        const data = chunk => {
            buffer += chunk;
            try {
                if (Buffer.byteLength(buffer) > MAX_BYTES) fail();
                const result = consume(buffer);
                if (result !== undefined) finish(null, result);
            } catch (error) { finish(error); }
        };
        const errorHandler = error => finish(new Error(error.code === 'ENOENT' ? 'missing' : 'unavailable'));
        const closed = () => finish(new Error('unavailable'));
        const timer = setTimeout(() => finish(new Error('unavailable')), 15000);
        child.stdout.setEncoding('utf8');
        child.stdout.on('data', data);
        child.once('error', errorHandler);
        child.once('close', closed);
    });
}

async function codex() {
    const child = launch('codex', ['app-server', '--listen', 'stdio://']);
    let initialized = false;
    try {
        const pending = outputUntil(child, buffer => {
            for (const line of buffer.split('\n').slice(0, -1)) {
                if (!line.trim()) continue;
                const message = JSON.parse(line);
                if (message.error && (message.id === 1 || message.id === 2))
                    fail(/auth|login|sign.in/i.test(message.error.message ?? '') ? 'auth' : 'unavailable');
                if (message.id === 1 && !initialized) {
                    initialized = true;
                    child.stdin.write(JSON.stringify({ method: 'initialized', params: {} }) + '\n');
                    child.stdin.write(JSON.stringify({ id: 2, method: 'account/rateLimits/read', params: { excludeResetCreditDetails: true } }) + '\n');
                }
                if (message.id === 2) return message.result ?? null;
            }
        });
        child.stdin.write(JSON.stringify({ id: 1, method: 'initialize', params: { clientInfo: { name: 'shoji_limits', version: '1.0' } } }) + '\n');
        return await pending;
    } finally { stop(child); }
}

async function fetchJson(url, token, headers = {}) {
    const response = await fetch(url, {
        headers: { accept: 'application/json', authorization: `Bearer ${token}`, ...headers },
        redirect: 'error', signal: AbortSignal.timeout(15000)
    });
    if (response.status === 401 || response.status === 403) fail('auth');
    if (!response.ok) fail();
    return JSON.parse((await responseBytes(response)).toString('utf8'));
}

async function responseBytes(response) {
    const chunks = [];
    let size = 0;
    for await (const chunk of response.body) {
        size += chunk.length;
        if (size > MAX_BYTES) fail();
        chunks.push(chunk);
    }
    return Buffer.concat(chunks);
}

// Read only the declared billing fields; unknown protobuf messages stay opaque.
function protobufFields(bytes) {
    const fields = new Map();
    let offset = 0;
    function varint() {
        let value = 0n;
        for (let i = 0; i < 10; i++) {
            if (offset >= bytes.length) fail();
            const b = bytes[offset++];
            if (i === 9 && b > 1) fail();
            value |= BigInt(b & 127) << BigInt(i * 7);
            if (!(b & 128)) return value;
        }
        fail();
    }
    while (offset < bytes.length) {
        const tag = varint();
        const id = Number(tag >> 3n), wire = Number(tag & 7n);
        if (id < 1 || id > 536870911) fail();
        let value;
        if (wire === 0) value = varint();
        else {
            const size = wire === 2 ? Number(varint()) : wire === 5 ? 4 : wire === 1 ? 8 : -1;
            if (!Number.isSafeInteger(size) || size < 0 || offset + size > bytes.length) fail();
            value = bytes.subarray(offset, offset + size);
            offset += size;
        }
        fields.set(id, [...(fields.get(id) || []), { wire, value }]);
    }
    return (id, wire) => {
        const entries = fields.get(id);
        if (!entries) return undefined;
        if (entries.length !== 1 || entries[0].wire !== wire) fail();
        return entries[0].value;
    };
}

function grokGrpcPercent(bytes, now = Date.now()) {
    let payload, status;
    for (let offset = 0; offset < bytes.length;) {
        if (offset + 5 > bytes.length) fail();
        const flags = bytes[offset], size = bytes.readUInt32BE(offset + 1);
        offset += 5;
        if (offset + size > bytes.length) fail();
        const frame = bytes.subarray(offset, offset + size);
        offset += size;
        if (flags === 0 && !payload && status === undefined) payload = frame;
        else if (flags === 128 && status === undefined) {
            const statuses = [...frame.toString('utf8').matchAll(/(?:^|\r\n)grpc-status:[ \t]*(\d+)(?=\r\n|$)/g)];
            if (statuses.length !== 1) fail();
            status = statuses[0][1];
        }
        else fail();
    }
    if (!payload || status !== '0') fail();
    const configBytes = protobufFields(payload)(1, 2);
    if (!configBytes) fail();
    const config = protobufFields(configBytes);
    const encoded = config(1, 5);
    if (encoded) {
        const percent = encoded.readFloatLE();
        if (!Number.isFinite(percent) || percent < 0 || percent > 100) fail();
        return percent;
    }
    const periodBytes = config(8, 2);
    if (!periodBytes) fail();
    const period = protobufFields(periodBytes);
    const type = period(1, 0);
    const time = id => {
        const message = period(id, 2);
        if (!message) fail();
        const fields = protobufFields(message);
        const seconds = fields(1, 0), nanos = fields(2, 0) ?? 0n;
        if (seconds === undefined || seconds > 8640000000000n || nanos >= 1000000000n) fail();
        return Number(seconds) * 1000 + Number(nanos) / 1000000;
    };
    // Proto3's omitted float means zero only after validating the active period.
    if ((type === 1n || type === 2n) && time(2) <= now && now < time(3)) return 0;
    fail();
}

async function grokGrpc(token) {
    const response = await fetch('https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig', {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(6000),
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/grpc-web+proto', 'x-grpc-web': '1' },
        body: Buffer.from([0, 0, 0, 0, 2, 8, 0])
    });
    if (!response.ok || !response.headers.get('content-type')?.includes('grpc') || ![null, '0'].includes(response.headers.get('grpc-status'))) fail();
    return grokGrpcPercent(await responseBytes(response));
}

function grokTokenResult(message) {
    if (message.error || message.result?.error) fail();
    const token = message.result?.result?.token;
    if (typeof token !== 'string' || !token.trim()) fail('auth');
    return token.trim();
}

async function grokToken() {
    // Let the CLI own token refresh and credential persistence, as in its own UI.
    const child = launch('grok', ['agent', '--no-leader', 'stdio']);
    let initialized = false;
    try {
        const pending = outputUntil(child, buffer => {
            for (const line of buffer.split('\n').slice(0, -1)) {
                if (!line.trim()) continue;
                const message = JSON.parse(line);
                if (message.id === 1 && !initialized) {
                    if (message.error) fail();
                    initialized = true;
                    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 2, method: '_x.ai/auth/getBearerToken', params: {} }) + '\n');
                }
                if (message.id === 2) return grokTokenResult(message);
            }
        });
        child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {
            protocolVersion: 1, clientCapabilities: {}, clientInfo: { name: 'shoji_limits', version: '1.0' }
        } }) + '\n');
        return await pending;
    } finally { stop(child); }
}

async function grok() {
    const token = await grokToken();
    const raw = await fetchJson('https://cli-chat-proxy.grok.com/v1/billing?format=credits', token, {
        'x-xai-token-auth': 'xai-grok-cli', 'user-agent': 'shoji-limits/1.0'
    });
    if (record(raw.config) && number(raw.config.creditUsagePercent) === null) {
        try { raw.config.creditUsagePercent = await grokGrpc(token); }
        catch { /* Keep the authenticated proxy response with unknown usage. */ }
    }
    return raw;
}

async function kimi() {
    const port = await new Promise((resolve, reject) => {
        const server = createServer();
        server.once('error', reject);
        server.listen(0, '127.0.0.1', () => {
            const port = server.address().port;
            server.close(error => error ? reject(error) : resolve(port));
        });
    });
    const child = launch('kimi', ['web', '--no-open', '--host', '127.0.0.1', '--port', String(port), '--log-level', 'silent']);
    try {
        const token = await outputUntil(child, buffer => buffer.match(/Local:\s+http:\/\/127\.0\.0\.1:\d+\/#token=([A-Za-z0-9_-]+)/)?.[1]);
        const result = await fetchJson(`http://127.0.0.1:${port}/api/v1/oauth/usage`, token);
        if (result.data?.kind !== 'ok') return result;
        // Let the CLI refresh OAuth, then read the raw counters: its web adapter
        // only exposes `usages`, which can be zero while `usage`/`limits` are not.
        const home = process.env.KIMI_CODE_HOME || join(homedir(), '.kimi-code');
        const credentials = JSON.parse(await readFile(join(home, 'credentials/kimi-code.json'), 'utf8'));
        if (typeof credentials.access_token !== 'string' || !credentials.access_token.trim()) fail('auth');
        return await fetchJson('https://api.kimi.com/coding/v1/usages', credentials.access_token);
    } finally { stop(child); }
}

if (process.argv.includes('--self-check')) {
    const { default: assert } = await import('node:assert/strict');
    assert.equal(resetCredits({ rateLimitResetCredits: { availableCount: 4 } }), 4);
    assert.equal(resetCredits({ rateLimitResetCredits: { availableCount: 0 } }), 0);
    assert.equal(resetCredits({ rateLimitResetCredits: null }), null);
    assert.equal(resetCredits({ rateLimitResetCredits: { availableCount: -1 } }), null);
    assert.equal(resetCredits({ rateLimitResetCredits: { availableCount: 1.5 } }), null);
    assert.equal(grokTokenResult({ result: { result: { token: ' refreshed-token ' } } }), 'refreshed-token');
    assert.throws(() => grokTokenResult({ result: { result: { token: null } } }), /auth/);
    assert.throws(() => grokTokenResult({ result: { error: 'offline' } }), /unavailable/);
    assert.throws(() => grokTokenResult({ error: { code: -32601 } }), /unavailable/);
    assert.deepEqual(normalize('codex', { rateLimits: { primary: { usedPercent: 39, windowDurationMins: 300, resetsAt: 1786160179 } } })[0],
        { label: '5 ч', minutes: 300, remaining: 61, resetsAt: 1786160179000 });
    assert.equal(normalize('grok', { config: { creditUsagePercent: '43' } })[0].remaining, 57);
    assert.equal(normalize('grok', { config: { currentPeriod: { end: '2026-09-28T00:00:00Z' } } })[0].remaining, null);
    assert.deepEqual(normalize('kimi', { usage: { limit: '100', used: '36' }, limits: [{ window: { duration: 5, unit: 'hour' }, detail: { limit: '100', remaining: '88' } }] }).map(w => w.remaining), [88, 64]);
    assert.deepEqual(normalize('kimi', {
        usage: { limit: '100', used: '31', remaining: '69' },
        limits: [{ window: { duration: 300, timeUnit: 'TIME_UNIT_MINUTE' }, detail: { limit: '100', used: '79', remaining: '21' } }],
        usages: { limit_5h: { used_ratio: 0 }, limit_7d: { used_ratio: 0 } }
    }).map(w => w.remaining), [21, 69]);
    assert.equal(normalize('kimi', { summary: { window: { duration: 7, unit: 'day' }, limit: 0, used: 0 } })[0].remaining, null);
    for (const provider of ['codex', 'grok', 'kimi']) assert.deepEqual(normalize(provider, {}), []);
    assert.equal(windowData(140, null, null).remaining, 0);
    assert.equal(windowData(null, null, null).remaining, null);
    assert.deepEqual(normalize('kimi', { code: 0, data: { kind: 'ok', quota: { usages: {
        limit5h: { usedRatio: 0.25, resetAt: '2026-09-28T00:00:00Z' }, limit7d: { usedRatio: 0 }
    } } } }).map(w => w.remaining), [75, 100]);
    assert.equal(normalize('kimi', { data: { kind: 'ok', quota: { usages: { limit5h: {} } } } })[0].remaining, null);
    const zeroUsage = Buffer.from('00000000440a4212001a00220b0888ede0d50610f8e9b8762a0b0888e285d60610f8e9b876421c0802120b0888ede0d50610f8e9b8761a0b0888e285d60610f8e9b876580162006801800000000f677270632d7374617475733a300d0a', 'hex');
    const duringPeriod = Date.parse('2026-09-28T00:00:00Z');
    assert.equal(grokGrpcPercent(zeroUsage, duringPeriod), 0);
    assert.throws(() => grokGrpcPercent(zeroUsage, Date.parse('2027-01-01T00:00:00Z')));
    assert.throws(() => grokGrpcPercent(zeroUsage.subarray(0, -1), duringPeriod));
    const nonzeroUsage = Buffer.concat([Buffer.from([0, 0, 0, 0, 7, 10, 5, 13, 0, 0, 200, 65]), zeroUsage.subarray(73)]);
    assert.equal(grokGrpcPercent(nonzeroUsage, duringPeriod), 25);
    assert.throws(() => protobufFields(Buffer.from([0])));
    assert.throws(() => protobufFields(Buffer.from([10, 127])));
    assert.throws(() => normalize('kimi', { data: { kind: 'error', status: 401 } }), /auth/);
    console.log('AI quota normalization: OK');
} else {
    for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
        for (const child of children) stop(child);
        setTimeout(() => process.exit(0), 600);
    });
    process.stdout.on('error', () => { for (const child of children) stop(child); process.exitCode = 1; });
    // ponytail: one-shot CLI readers avoid idle servers; keep connections only if startup cost becomes noticeable.
    await Promise.all(Object.entries({ codex, grok, kimi }).map(async ([id, read]) => {
        try {
            const raw = await read();
            const windows = normalize(id, raw);
            if (!windows.length) fail();
            process.stdout.write(JSON.stringify({ id, state: 'available', fetchedAt: Date.now(), windows,
                ...(id === 'codex' ? { resetCredits: resetCredits(raw) } : {}) }) + '\n');
        } catch (error) {
            process.stdout.write(JSON.stringify({ id, state: ['auth', 'missing'].includes(error.message) ? error.message : 'unavailable', windows: [] }) + '\n');
        }
    }));
}
