pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Whatever is playing.
//
// A singleton because the position has to be polled -- MPRIS does not push it
// -- and one poll for the shell is enough however many screens are showing it.
Singleton {
    id: root
    property bool active: false

    readonly property var players: Mpris.players ? Mpris.players.values : []

    // The one that is playing, else the one that could be. Derived rather than
    // remembered, so a player that quits cannot leave the row pointing at it.
    readonly property var player: {
        var playing = null;
        var any = null;
        for (var i = 0; i < players.length; i++) {
            var candidate = players[i];
            if (!any)
                any = candidate;
            if (!playing && candidate.isPlaying)
                playing = candidate;
        }
        return playing || any;
    }

    readonly property bool usable: player !== null && player !== undefined
    readonly property string title: usable && player.trackTitle
        ? player.trackTitle : ""
    readonly property string artist: usable && player.trackArtist
        ? player.trackArtist : ""
    readonly property string art: usable && player.trackArtUrl
        ? player.trackArtUrl : ""
    readonly property bool playing: usable && player.isPlaying

    // Polled, not pushed. Only while something is actually playing: a paused
    // player's position does not move, and the whole layer repaints when this
    // changes.
    property real position: 0
    readonly property real length: usable && player.lengthSupported
        ? player.length : 0

    Timer {
        running: root.active && root.playing && root.usable && root.player.positionSupported
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player.position
    }

    onPlayerChanged: position = usable && player.positionSupported
        ? player.position : 0

    Connections {
        target: root.player
        function onTrackChanged(): void { root.position = root.player.positionSupported ? root.player.position : 0; }
        function onPositionChanged(): void { root.position = root.player.positionSupported ? root.player.position : 0; }
    }

    function toggle() {
        if (usable && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (usable && player.canGoNext)
            player.next();
    }

    function previous() {
        if (usable && player.canGoPrevious)
            player.previous();
    }

    function seekFraction(fraction) {
        if (!usable || !player.canSeek || length <= 0)
            return;
        var target = Math.max(0, Math.min(1, fraction)) * length;
        player.position = target;
        position = target;
    }

    function clock(seconds) {
        if (!(seconds > 0))
            return "0:00";
        var total = Math.floor(seconds);
        var minutes = Math.floor(total / 60);
        var rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }
}
