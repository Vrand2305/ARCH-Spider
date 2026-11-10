import QtQuick 2.15
import QtQml.Models 2.3
import org.kde.plasma.private.mpris as Mpris

QtObject {
    id: root

    property var mpris2Model: Mpris.Mpris2Model {
        readonly property alias preferredSourceIdentities: root.sourceIdentities
        property var preferredPlayersConnections: []
        property var autoPlayersConnections: []

        onRowsInserted: () => updatePlayerIndex(this)
        onRowsRemoved: () => updatePlayerIndex(this)
        onPreferredSourceIdentitiesChanged: () => updatePlayerIndex(this)

        function updatePlayerIndex(model) {
            clearAutoPlayersConnections();
            if (!preferredSourceIdentities) {
                // Automatic mode: score-based selection instead of blind row 0,
                // which may be a stale/dead registration (e.g. a closed
                // Chromium tab) or a multiplexer that does not reflect the
                // really-playing player.
                model.currentIndex = pickBestPlayerIndex(model);
                watchAutoPlayers(model);
                return;
            }

            clearAllPlayersConnections();

            const preferredModels = [];
            const CONTAINER_ROLE = Qt.UserRole + 1;
            for (let i = 1; i < model.rowCount(); i++) {
                const player = model.data(model.index(i, 0), CONTAINER_ROLE);
                if (preferredSourceIdentities.includes(player.identity)) {
                    preferredModels.push({
                        player: player,
                        index: i
                    });
                }
            }

            // If only one preferred players have been setup, directly use it
            if (preferredSourceIdentities.length === 1) {
                if (preferredModels.length > 0) {
                    model.currentIndex = preferredModels[0].index;
                }
                return;
            }

            // In case of multiple preferred players we replicate the multiplexer logic
            // and use the following:
            // 1. the first currently playing player
            // 2. the first opened player
            //
            // Additionally, on each player status change switch to the player:
            // 1. that just started playing if none of the players were playing before
            // 2. that is still playing if the current player was paused
            for (let model of preferredModels) {
                const handler = function () {
                    const rootModel = root.mpris2Model;

                    if (rootModel.currentPlayer?.playbackStatus === Mpris.PlaybackStatus.Playing) {
                        return;
                    }

                    const status = model.player.playbackStatus;
                    if (status === Mpris.PlaybackStatus.Playing) {
                        rootModel.currentIndex = model.index;
                        return;
                    }

                    if (status === Mpris.PlaybackStatus.Paused) {
                        for (let otherModels of preferredModels) {
                            if (otherModels.player.playbackStatus === Mpris.PlaybackStatus.Playing) {
                                rootModel.currentIndex = otherModels.index;
                                return;
                            }
                        }
                    }
                };

                model.player.playbackStatusChanged.connect(handler);
                preferredPlayersConnections.push({
                    player: model.player,
                    handler: handler
                });
            }

            for (let entry of preferredModels) {
                if (entry.player.playbackStatus === Mpris.PlaybackStatus.Playing) {
                    model.currentIndex = entry.index;
                    return;
                }
            }

            if (preferredModels.length > 0) {
                model.currentIndex = preferredModels[0].index;
                return;
            }
        }

        function clearAllPlayersConnections() {
            for (let connection of preferredPlayersConnections) {
                connection.player.playbackStatusChanged.disconnect(connection.handler);
            }
            preferredPlayersConnections = [];
        }

        // Best-player scoring for automatic mode. Priority:
        // 1. PlaybackStatus == Playing with a real title
        // 2. Spotify (matched by identity substring, so instance suffixes
        //    like .chromium.instanceN-style names never matter) with a title
        // 3. Any player with a real title
        // Entries that do not answer on DBus, carry no metadata or have no
        // title are skipped, so dead registrations can never be selected.
        function pickBestPlayerIndex(model) {
            const CONTAINER_ROLE = Qt.UserRole + 1;
            const rowCount = model.rowCount();
            let spotifyIndex = -1;
            let fallbackIndex = -1;
            for (let i = 0; i < rowCount; i++) {
                let player = null;
                try {
                    player = model.data(model.index(i, 0), CONTAINER_ROLE);
                } catch (e) {
                    continue; // unreadable row -> treat as dead
                }
                if (!player) {
                    continue;
                }
                let hasTitle = false;
                let playing = false;
                let isSpotify = false;
                try {
                    hasTitle = !!player.track;
                    playing = (player.playbackStatus === Mpris.PlaybackStatus.Playing);
                    isSpotify = (player.identity || "").toLowerCase().indexOf("spotify") !== -1;
                } catch (e) {
                    continue; // unreadable properties -> treat as dead
                }
                if (!hasTitle) {
                    continue;
                }
                if (playing) {
                    return i;
                }
                if (isSpotify && spotifyIndex === -1) {
                    spotifyIndex = i;
                }
                if (fallbackIndex === -1) {
                    fallbackIndex = i;
                }
            }
            if (spotifyIndex !== -1) {
                return spotifyIndex;
            }
            if (fallbackIndex !== -1) {
                return fallbackIndex;
            }
            return 0;
        }

        function clearAutoPlayersConnections() {
            for (let connection of autoPlayersConnections) {
                try {
                    connection.player.playbackStatusChanged.disconnect(connection.handler);
                } catch (e) {
                    // already gone -> nothing to disconnect
                }
            }
            autoPlayersConnections = [];
        }

        // Re-run the selection whenever any player's status changes, so a
        // newly-playing player takes over without needing a restart.
        // Setting currentIndex never emits playbackStatusChanged, so this
        // cannot loop.
        function watchAutoPlayers(model) {
            clearAutoPlayersConnections();
            const CONTAINER_ROLE = Qt.UserRole + 1;
            for (let i = 0; i < model.rowCount(); i++) {
                let player = null;
                try {
                    player = model.data(model.index(i, 0), CONTAINER_ROLE);
                } catch (e) {
                    continue;
                }
                if (!player || !player.playbackStatusChanged) {
                    continue;
                }
                const handler = function () {
                    updatePlayerIndex(model);
                };
                try {
                    player.playbackStatusChanged.connect(handler);
                    autoPlayersConnections.push({ player: player, handler: handler });
                } catch (e) {
                    // cannot watch this player -> skip it
                }
            }
        }
    }

    property var sourceIdentities: null
    readonly property bool ready: {
        if (!mpris2Model.currentPlayer) {
            return false;
        }
        if (sourceIdentities && !sourceIdentities.includes(mpris2Model.currentPlayer.identity)) {
            return false;
        }
        // Chromium-based browsers stay registered on MPRIS even after the media tab
        // is closed, without clearing their metadata. Requiring actual metadata
        // prevents the widget from staying visible in that case.
        return !!(mpris2Model.currentPlayer.track
               || mpris2Model.currentPlayer.artist
               || mpris2Model.currentPlayer.album);
    }

    readonly property string artists: ready ? mpris2Model.currentPlayer.artist : ""
    readonly property string title: ready ? mpris2Model.currentPlayer.track : ""
    readonly property string album: ready ? mpris2Model.currentPlayer.album : ""
    readonly property int playbackStatus: ready ? mpris2Model.currentPlayer.playbackStatus : Mpris.PlaybackStatus.Unknown
    readonly property int shuffle: ready ? mpris2Model.currentPlayer.shuffle : Mpris.ShuffleStatus.Unknown
    readonly property string artUrl: ready ? mpris2Model.currentPlayer.artUrl : ""
    readonly property int loopStatus: ready ? mpris2Model.currentPlayer.loopStatus : Mpris.LoopStatus.Unknown
    readonly property double songPosition: ready ? mpris2Model.currentPlayer.position : 0
    readonly property double songLength: ready ? mpris2Model.currentPlayer.length : 0
    readonly property real volume: ready ? mpris2Model.currentPlayer.volume : 0
    readonly property string identity: ready ? mpris2Model.currentPlayer.identity : ""

    readonly property bool canGoNext: ready ? mpris2Model.currentPlayer.canGoNext : false
    readonly property bool canGoPrevious: ready ? mpris2Model.currentPlayer.canGoPrevious : false
    readonly property bool canPlay: ready ? mpris2Model.currentPlayer.canPlay : false
    readonly property bool canPause: ready ? mpris2Model.currentPlayer.canPause : false
    readonly property bool canSeek: ready ? mpris2Model.currentPlayer.canSeek : false
    readonly property bool canRaise: ready ? mpris2Model.currentPlayer.canRaise : false

    // To know whether Shuffle and Loop can be changed we have to check if the property is defined,
    // unlike the other commands, LoopStatus and Shuffle hasn't a specific propety such as
    // CanPause, CanSeek, etc.
    readonly property bool canChangeShuffle: ready ? mpris2Model.currentPlayer.shuffle != undefined : false
    readonly property bool canChangeLoopStatus: ready ? mpris2Model.currentPlayer.loopStatus != undefined : false

    function playPause() {
        mpris2Model.currentPlayer?.PlayPause();
    }

    function setPosition(position) {
        mpris2Model.currentPlayer.position = position;
    }

    function next() {
        mpris2Model.currentPlayer?.Next();
    }

    function previous() {
        mpris2Model.currentPlayer?.Previous();
    }

    function updatePosition() {
        mpris2Model.currentPlayer?.updatePosition();
    }

    function setVolume(volume) {
        mpris2Model.currentPlayer.volume = volume;
    }

    function changeVolume(delta, showOSD) {
        mpris2Model.currentPlayer.changeVolume(delta, showOSD);
    }

    function setShuffle(shuffle) {
        mpris2Model.currentPlayer.shuffle = shuffle;
    }

    function setLoopStatus(loopStatus) {
        mpris2Model.currentPlayer.loopStatus = loopStatus;
    }

    function raise() {
        mpris2Model.currentPlayer.Raise();
    }
}
