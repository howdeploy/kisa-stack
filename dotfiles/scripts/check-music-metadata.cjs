const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const code = fs.readFileSync(path.join(__dirname, '../config/shoji-shell/MusicWidget.qml'), 'utf8');
assert.ok(!code.includes('XMLHttpRequest') && !code.includes('oembed'));
const integrated = {
    dbusName: 'org.mpris.MediaPlayer2.plasma-browser-integration', isPlaying: false,
    metadata: { 'kde:pid': 42, 'xesam:url': 'https://www.youtube.com/watch?v=firstVideo1',
        'xesam:title': 'First video', 'xesam:artist': ['First artist'], 'mpris:artUrl': 'file:///tmp/first.jpg' },
    get trackTitle() { return this.metadata['xesam:title'] || ''; },
    get trackArtist() { return (this.metadata['xesam:artist'] || []).join(', '); },
    get trackArtUrl() { return this.metadata['mpris:artUrl'] || ''; },
};
const native = {
    dbusName: 'org.mpris.MediaPlayer2.brave.instance42', isPlaying: true, metadata: {},
    trackTitle: '(5) First video - YouTube', trackArtist: '', trackArtUrl: '',
};
const mirror = { ...integrated, dbusName: 'org.mpris.MediaPlayer2.playerctld' };
const scope = {
    capturePid: 42, spectrumAvailable: true, ambiguousAudio: false,
    Mpris: { players: { values: [integrated, native, mirror] } },
    youtubeTrack: {},
};
scope.root = scope;
vm.createContext(scope);
const start = code.indexOf('    function sourceName(');
const nativeStart = code.indexOf('    readonly property var nativePlayer:', start);
const playerStart = code.indexOf('    readonly property var player:', nativeStart);
const end = code.indexOf('    readonly property string source:', playerStart);
vm.runInContext(code.slice(start, nativeStart), scope);
const nativeExpression = code.slice(nativeStart, playerStart).split('nativePlayer:')[1].trim();
Object.defineProperty(scope, 'nativePlayer', { get: () => vm.runInContext('(' + nativeExpression + ')', scope) });
vm.runInContext(code.slice(playerStart, end).replace('    readonly property var player: {', 'function selectPlayer() {'), scope);
Object.defineProperty(scope, 'player', { get: () => scope.selectPlayer() });
vm.runInContext(code.slice(code.indexOf('    function youtubeTitle('), code.indexOf('    readonly property string currentYoutubeTitle:')), scope);
for (const name of ['source', 'currentYoutubeTitle', 'title', 'artist', 'artwork']) {
    const match = code.match(new RegExp('readonly property string ' + name + ': ([\\s\\S]*?)(?=\\n    (?:readonly )?property)'));
    const expression = match[1].replace(/\n\s*\/\/[^\n]*/g, '');
    Object.defineProperty(scope, name, { get: () => vm.runInContext('(' + expression + ')', scope) });
}
vm.runInContext('function getYoutubeCandidate() ' + code.match(/readonly property var youtubeCandidate: (\{[\s\S]*?)\n    onYoutubeCandidateChanged:/)[1], scope);
Object.defineProperty(scope, 'youtubeCandidate', { get: () => scope.getYoutubeCandidate() });
const handler = code.slice(code.indexOf('    onYoutubeCandidateChanged:') + '    onYoutubeCandidateChanged:'.length, code.indexOf('    readonly property string title:'));
vm.runInContext('function updateYoutubeTrack() ' + handler, scope);

assert.equal(scope.player, integrated);
scope.updateYoutubeTrack();
assert.equal(scope.title, 'First video');
assert.equal(scope.artist, 'First artist');
assert.equal(scope.artwork, 'file:///tmp/first.jpg');

// A muted preview must not replace the cached metadata of the audible video.
integrated.metadata['mpris:length'] = 8000000000;
integrated.metadata['xesam:title'] = 'Another preview';
integrated.metadata['xesam:artist'] = ['Wrong artist'];
integrated.metadata['mpris:artUrl'] = 'file:///tmp/preview.jpg';
scope.updateYoutubeTrack();
assert.equal(scope.player, integrated);
assert.equal(scope.title, 'First video');
assert.equal(scope.artist, 'First artist');
assert.equal(scope.artwork, 'file:///tmp/first.jpg');

// Playlist transitions can leave the watch URL unchanged; the native title wins.
native.trackTitle = '(6) Next video - YouTube';
assert.equal(scope.title, 'Next video');
assert.equal(scope.artist, 'YouTube');
assert.equal(scope.artwork, '');
integrated.metadata['xesam:title'] = 'Next video';
integrated.metadata['xesam:artist'] = ['Next artist'];
integrated.metadata['mpris:artUrl'] = 'file:///tmp/first.jpg';
scope.updateYoutubeTrack();
scope.updateYoutubeTrack();
assert.equal(scope.artist, 'Next artist');
assert.equal(scope.artwork, '');
integrated.metadata['mpris:artUrl'] = 'file:///tmp/next.jpg';
scope.updateYoutubeTrack();
assert.equal(scope.artwork, 'file:///tmp/next.jpg');
assert.ok(integrated.metadata['xesam:url'].endsWith('firstVideo1'));

native.isPlaying = false;
integrated.metadata['xesam:url'] = 'https://music.example.org/';
integrated.metadata['xesam:title'] = 'Local track';
integrated.metadata['xesam:artist'] = ['Local artist'];
integrated.metadata['mpris:artUrl'] = 'https://music.example.org/cover.jpg';
assert.equal(scope.title, 'Local track');
assert.equal(scope.artist, 'Local artist');
assert.equal(scope.artwork, integrated.trackArtUrl);
native.isPlaying = true;
assert.equal(scope.player, native);
scope.spectrumAvailable = false;
assert.equal(scope.player, null);
scope.spectrumAvailable = true;
scope.capturePid = 99;
assert.equal(scope.player, null);
scope.capturePid = 42;
scope.ambiguousAudio = true;
assert.equal(scope.player, null);
console.log('Music metadata: native titles, stale URLs, preview rejection and artwork transitions OK');
