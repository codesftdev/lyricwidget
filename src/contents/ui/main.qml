import "./components"
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris


PlasmoidItem {
    id: widget

    Plasmoid.status: (showWhenNoMedia || player.ready) ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    Plasmoid.backgroundHints: plasmoid.configuration.desktopWidgetBg

    readonly property int formFactor: Plasmoid.formFactor
    readonly property int location: Plasmoid.location
    readonly property bool showWhenNoMedia: plasmoid.configuration.showWhenNoMedia
    readonly property bool hidePlayerControlBinds: plasmoid.configuration.hidePlayerControlBindsInHoverTooltip

    readonly property font baseFont: plasmoid.configuration.useCustomFont ? plasmoid.configuration.customFont : Kirigami.Theme.defaultFont

    // Runtime state properties - independent per widget instance
    property bool panelContentHidden: false
    property bool lyricsVisible: true

    toolTipTextFormat: Text.PlainText
    toolTipMainText: player.playbackStatus > Mpris.PlaybackStatus.Stopped ? player.title : i18n("No media playing")
    toolTipSubText: {
        let text = player.artists ? i18nc("%1 is the media artist/author and %2 is the player name", "by %1 (%2)", player.artists, player.identity)
            : i18nc("%1 is the player name", "%1", player.identity)
        if(!hidePlayerControlBinds){
            text += "\n" + (player.playbackStatus === Mpris.PlaybackStatus.Playing ? i18n("Middle-click to pause") : i18n("Middle-click to play"))
            text += "\n" + i18n("Scroll to adjust volume")
            text += "\n" + (player.canRaise ? i18n("Ctrl+Click to bring player to the front") : i18n("This player can't be raised"))
        }
        return text
    }

    onShowWhenNoMediaChanged: {
        Plasmoid.status = (showWhenNoMedia || player.ready) ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    }

    Player {
        id: player
        sourceIdentity: {
            if (!plasmoid.configuration.choosePlayerAutomatically) {
                return plasmoid.configuration.preferredPlayerIdentity
            }
        }
        onReadyChanged: {
            Plasmoid.status = (showWhenNoMedia || player.ready) ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
            console.debug(`Player ready changed: ${player.ready} -> plasmoid status changed: ${Plasmoid.status}`)
        }
    }

    LyricsManager {
        id: lyricsManager
        title: player.title
        artists: player.artists
        album: player.album
        duration: player.songLength
        position: player.songPosition
    }

    // Context menu actions for right-click
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: panelContentHidden ? i18n("Show Panel Content") : i18n("Hide Panel Content")
            icon.name: panelContentHidden ? "view-visible" : "view-hidden"
            onTriggered: {
                panelContentHidden = !panelContentHidden
            }
        },
        PlasmaCore.Action {
            text: lyricsVisible ? i18n("Hide Lyrics") : i18n("Show Lyrics")
            icon.name: lyricsVisible ? "view-hidden" : "view-visible"
            onTriggered: {
                lyricsVisible = !lyricsVisible
            }
        }
    ]

    compactRepresentation: Compact {}
    fullRepresentation: Full {}
}
