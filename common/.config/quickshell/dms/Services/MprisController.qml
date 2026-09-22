pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: {
        const players = Mpris.players.values;
        const excluded = SettingsData.mediaExcludePlayers || [];
        if (excluded.length === 0)
            return players;
        return players.filter(p => {
            const identity = (p.identity || "").toLowerCase();
            const desktopEntry = ("desktopEntry" in p && p.desktopEntry) ? String(p.desktopEntry).toLowerCase() : "";
            return !excluded.some(ex => {
                const exLower = String(ex).toLowerCase().trim();
                if (!exLower)
                    return false;

                // 1. Substring match
                if (identity.includes(exLower) || desktopEntry.includes(exLower))
                    return true;

                // 2. Match reverse-DNS segments (e.g. app.zen_browser.zen -> zen)
                if (exLower.indexOf(".") !== -1) {
                    const parts = exLower.split(".");
                    const lastPart = parts[parts.length - 1];
                    if (lastPart && (identity.includes(lastPart) || desktopEntry.includes(lastPart)))
                        return true;
                }

                // 3. Bidirectional match (longer excluded name contains shorter player identity)
                if (identity.length >= 3 && exLower.includes(identity))
                    return true;

                return false;
            });
        });
    }
    property MprisPlayer activePlayer: null
    property real activePlayerStableLength: 0
    // Chromium can report blank metadata between tracks
    property string stableTitle: ""
    property string stableArtist: ""

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() {
            root.activePlayerStableLength = (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) ? root.activePlayer.length : 0;
            root._syncStableMeta();
            root._checkIdle();
        }
        function onTrackArtistChanged() {
            root._syncStableMeta();
            root._checkIdle();
        }
        function onLengthChanged() {
            if (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) {
                root.activePlayerStableLength = root.activePlayer.length;
            }
        }
        function onPlaybackStateChanged() {
            root._syncStableMeta();
            root._checkIdle();
        }
    }

    onActivePlayerChanged: {
        activePlayerStableLength = (activePlayer && activePlayer.lengthSupported && activePlayer.length > 1) ? activePlayer.length : 0;
        stableTitle = activePlayer?.trackTitle || "";
        stableArtist = activePlayer?.trackArtist || "";
        _checkIdle();
    }

    function _syncStableMeta(): void {
        const p = activePlayer;
        if (!p) {
            stableTitle = "";
            stableArtist = "";
            return;
        }
        if (isFirefoxYoutubeHoverPreview(p))
            return;
        if (p.trackTitle)
            stableTitle = p.trackTitle;
        if (p.trackArtist)
            stableArtist = p.trackArtist;
    }

    // Chromium reports stopped media w/blank metadata, resolve by checking idle status
    Timer {
        id: _idleGraceTimer
        interval: 1223
        onTriggered: {
            if (!root.isIdle(root.activePlayer))
                return;
            root.stableTitle = "";
            root.stableArtist = "";
            root._resolveActivePlayer();
        }
    }

    function _checkIdle(): void {
        if (!isIdle(activePlayer)) {
            _idleGraceTimer.stop();
            return;
        }
        if (!_idleGraceTimer.running)
            _idleGraceTimer.start();
    }

    onAvailablePlayersChanged: _resolveActivePlayer()
    Component.onCompleted: _resolveActivePlayer()

    Connections {
        target: SettingsData
        function onMediaPriorityPlayersChanged() {
            root._resolveActivePlayer();
        }
    }

    // Some players report Stopped with blank metadata between tracks. Wait
    // briefly before leaving them, and cancel if playback resumes. A real
    // pause is handled immediately so volume edits are not applied to the
    // player that just paused.
    Timer {
        id: _yieldTimer
        interval: 500
        onTriggered: root._resolveActivePlayer()
    }

    Instantiator {
        model: root.availablePlayers
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                root._notePlaybackChanged(modelData);
            }
        }
    }

    function isIdle(player: MprisPlayer): bool {
        return player && player.playbackState === MprisPlaybackState.Stopped && !player.trackTitle && !player.trackArtist;
    }

    function playerMatchesPattern(player: MprisPlayer, pattern: string): bool {
        const pat = pattern.toLowerCase().trim();
        if (!pat)
            return false;
        const identity = (player.identity || "").toLowerCase();
        const desktopEntry = ("desktopEntry" in player && player.desktopEntry) ? String(player.desktopEntry).toLowerCase() : "";
        if (identity.includes(pat) || desktopEntry.includes(pat))
            return true;
        if (pat.indexOf(".") !== -1) {
            const parts = pat.split(".");
            const lastPart = parts[parts.length - 1];
            if (lastPart && (identity.includes(lastPart) || desktopEntry.includes(lastPart)))
                return true;
        }
        if (identity.length >= 3 && pat.includes(identity))
            return true;
        return false;
    }

    function isRealPlayback(player: MprisPlayer): bool {
        return !!player && player.isPlaying && !isFirefoxYoutubeHoverPreview(player);
    }

    // playingOnly: the priority player must be playing. Otherwise any
    // non-idle match counts, so a paused priority player can still be the
    // fallback when nothing is playing.
    function findPriorityPlayer(playingOnly: bool): MprisPlayer {
        const prios = SettingsData.mediaPriorityPlayers || [];
        for (let i = 0; i < prios.length; i++) {
            const match = availablePlayers.find(p => {
                if (!playerMatchesPattern(p, String(prios[i])))
                    return false;
                if (playingOnly)
                    return isRealPlayback(p);
                return !isIdle(p);
            });
            if (match)
                return match;
        }
        return null;
    }

    function _adopt(player: MprisPlayer): void {
        if (!player || activePlayer === player)
            return;
        activePlayer = player;
        _persistIdentity(player.identity);
    }

    function _notePlaybackChanged(player: MprisPlayer): void {
        if (!player)
            return;
        if (player.isPlaying) {
            _yieldTimer.stop();
            _resolveActivePlayer();
            return;
        }
        if (player !== activePlayer)
            return;
        if (player.playbackState === MprisPlaybackState.Paused) {
            _yieldTimer.stop();
            _resolveActivePlayer();
            return;
        }
        _yieldTimer.restart();
    }

    function _resolveActivePlayer(): void {
        // A playing priority player wins. If it is paused, a playing player
        // takes the widget until that player pauses too.
        const playingPriority = findPriorityPlayer(true);
        if (playingPriority) {
            _adopt(playingPriority);
            return;
        }
        const playing = availablePlayers.find(p => isRealPlayback(p));
        if (playing) {
            _adopt(playing);
            return;
        }
        // Nothing is playing, so a paused priority player wins over other
        // paused players. A metadata blip keeps the current player until the
        // idle grace timer decides it is really gone.
        const metadataBlip = activePlayer && isIdle(activePlayer) && _idleGraceTimer.running;
        if (!metadataBlip) {
            const pausedPriority = findPriorityPlayer(false);
            if (pausedPriority) {
                _adopt(pausedPriority);
                return;
            }
        }
        if (activePlayer && availablePlayers.indexOf(activePlayer) >= 0 && (!isIdle(activePlayer) || _idleGraceTimer.running))
            return;
        if (activePlayer && availablePlayers.indexOf(activePlayer) < 0) {
            const successor = availablePlayers.find(p => p.identity === activePlayer.identity);
            if (successor) {
                activePlayer = successor;
                return;
            }
        }
        const savedId = SessionData.lastPlayerIdentity;
        if (savedId) {
            const match = availablePlayers.find(p => p.identity === savedId);
            if (match && !isIdle(match)) {
                activePlayer = match;
                return;
            }
        }
        activePlayer = availablePlayers.find(p => p.canControl && !isIdle(p)) ?? null;
        if (activePlayer)
            _persistIdentity(activePlayer.identity);
    }

    function setActivePlayer(player: MprisPlayer): void {
        activePlayer = player;
        if (player)
            _persistIdentity(player.identity);
    }

    function _persistIdentity(identity: string): void {
        if (identity && SessionData.lastPlayerIdentity !== identity)
            SessionData.set("lastPlayerIdentity", identity);
    }

    Timer {
        interval: 1000
        running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    function isFirefoxYoutubeHoverPreview(player: MprisPlayer): bool {
        if (!player)
            return false;
        const id = (player.identity || "").toLowerCase();
        if (!id.includes("firefox"))
            return false;
        const url = (player.metadata?.["xesam:url"] || "").toString();
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url);
    }

    function previousOrRewind(): void {
        if (!activePlayer)
            return;
        if (activePlayer.position > 8 && activePlayer.canSeek)
            activePlayer.position = 0.1;
        else if (activePlayer.canGoPrevious)
            activePlayer.previous();
    }

    function next(): void {
        const player = activePlayer;
        if (player?.canGoNext)
            player.next();
    }
}
