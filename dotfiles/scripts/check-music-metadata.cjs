const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const code = fs.readFileSync(path.join(__dirname, '../config/shoji-shell/MusicWidget.qml'), 'utf8');
const requests = [];
class Request {
    static DONE = 4;
    open(method, url) { this.url = url; }
    send() { requests.push(this); }
    abort() { this.aborted = true; }
    finish(value, status = 200) {
        this.status = status;
        this.responseText = typeof value === 'string' ? value : JSON.stringify(value);
        this.readyState = Request.DONE;
        this.onreadystatechange();
    }
}
const integrated = {
    dbusName: 'org.mpris.MediaPlayer2.plasma-browser-integration', isPlaying: false,
    metadata: { 'kde:pid': 42, 'xesam:url': 'https://www.youtube.com/watch?v=firstVideo1' },
    trackTitle: 'Unrelated preview', trackArtist: 'Unrelated channel', trackArtUrl: 'file:///tmp/stale-artwork.jpg',
};
const native = {
    dbusName: 'org.mpris.MediaPlayer2.brave.instance42', isPlaying: true, metadata: {},
    trackTitle: '(5) First video - YouTube', trackArtist: '', trackArtUrl: '',
};
const mirror = { ...integrated, dbusName: 'org.mpris.MediaPlayer2.playerctld' };
const scope = {
    capturePid: 42, spectrumAvailable: true, ambiguousAudio: false,
    Mpris: { players: { values: [integrated, native, mirror] } },
    youtubeTrack: {}, youtubeRequest: null, XMLHttpRequest: Request,
    youtubeDeadline: { stop() {}, restart() {} },
};
scope.root = scope;
vm.createContext(scope);
const start = code.indexOf('    function sourceName(');
const end = code.indexOf('    readonly property string source:', start);
vm.runInContext(code.slice(start, end).replace('    readonly property var player: {', 'function selectPlayer() {'), scope);
Object.defineProperty(scope, 'player', { get: () => scope.selectPlayer() });
vm.runInContext('function getYoutubeVideoId() ' + code.match(/readonly property string youtubeVideoId: (\{[\s\S]*?)\n    property var youtubeTrack:/)[1], scope);
Object.defineProperty(scope, 'youtubeVideoId', { get: () => scope.getYoutubeVideoId() });
for (const name of ['source', 'title', 'artist', 'artwork']) {
    const match = code.match(new RegExp('readonly property string ' + name + ': ([\\s\\S]*?)(?=\\n    (?:readonly )?property)'));
    const expression = match[1].replace(/\n\s*\/\/[^\n]*/g, '');
    Object.defineProperty(scope, name, { get: () => vm.runInContext('(' + expression + ')', scope) });
}
vm.runInContext(code.slice(code.indexOf('    function loadYoutubeTrack()'), code.indexOf('    onYoutubeVideoIdChanged:')), scope);

assert.equal(scope.player, integrated);
assert.equal(scope.youtubeVideoId, 'firstVideo1');
scope.loadYoutubeTrack();
assert.equal(scope.title, 'Загрузка трека…');
assert.equal(scope.artist, 'YouTube');
assert.equal(scope.artwork, 'https://i.ytimg.com/vi/firstVideo1/hqdefault.jpg');
requests.at(-1).finish({ title: 'First video', author_name: 'First channel' });
assert.equal(scope.title, 'First video');
assert.equal(scope.artist, 'First channel');

// Preview metadata and the playerctld mirror must not replace the current video.
integrated.metadata['mpris:length'] = 8000000000;
integrated.trackTitle = 'Another preview';
assert.equal(scope.player, integrated);
assert.equal(scope.title, 'First video');
scope.loadYoutubeTrack();
const late = requests.at(-1);
integrated.metadata['xesam:url'] = 'https://www.youtube.com/watch?list=example&v=nextVideo22';
scope.loadYoutubeTrack();
assert.ok(late.aborted);
late.finish({ title: 'Old response', author_name: 'Old channel' });
assert.equal(scope.title, 'Загрузка трека…');
requests.at(-1).finish({ title: 'Next video', author_name: 'Next channel' });
assert.equal(scope.title, 'Next video');
assert.equal(scope.artist, 'Next channel');
assert.equal(scope.artwork, 'https://i.ytimg.com/vi/nextVideo22/hqdefault.jpg');
scope.loadYoutubeTrack();
requests.at(-1).finish('invalid JSON');
assert.equal(scope.title, 'Название недоступно');
scope.loadYoutubeTrack();
requests.at(-1).finish({}, 403);
assert.equal(scope.artist, 'YouTube');
integrated.metadata['xesam:url'] = 'https://www.youtube.com/shorts/nextVideo22';
assert.equal(scope.youtubeVideoId, 'nextVideo22');
integrated.metadata['xesam:url'] = 'https://www.youtube.com/watch?v=nextVideo22x';
assert.equal(scope.youtubeVideoId, '');

native.isPlaying = false;
integrated.metadata['xesam:url'] = 'https://music.example.org/';
integrated.trackTitle = 'Local track';
integrated.trackArtist = 'Local artist';
integrated.trackArtUrl = 'https://music.example.org/cover.jpg';
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
console.log('Music metadata: playback selection, video changes, stale responses and source ownership OK');
