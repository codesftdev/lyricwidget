import "./components"
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris


Item {
    id: compact

    readonly property bool horizontal: widget.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool fillAvailableSpace: plasmoid.configuration.fillAvailableSpace

    readonly property bool thirdLineVisible: plasmoid.configuration.thirdLineContent !== 0

    Layout.preferredWidth: horizontal ? contentColumn.implicitWidth + lengthMargin * 2 : contentColumn.implicitWidth
    Layout.preferredHeight: !horizontal ? contentColumn.implicitHeight + lengthMargin * 2 : contentColumn.implicitHeight
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight
    Layout.fillHeight: horizontal || fillAvailableSpace
    Layout.fillWidth: !horizontal || fillAvailableSpace

    readonly property int widgetThickness: horizontal ? height : width
    readonly property int widgetLength: horizontal ? width : height
    
    // Font metrics to calculate text heights
    FontMetrics {
        id: baseFontMetrics
        font: baseFont
    }
    
    FontMetrics {
        id: scaledFontMetrics
        font: compact.scaledFont
    }
    
    // Scaled line height for layout calculations
    readonly property real scaledLineHeight: scaledFontMetrics.height
    
    // Calculate font scale factor to fit all content within panel thickness.
    // Horizontal panel layout: ColumnLayout [ grid(1 row) | thirdLine ]
    // Grid row height = max(icon, controls, songText).
    // Total height = max(icon/controls, songText) + thirdLine + spacing
    // Icons/controls use availableThickness = widgetThickness - thirdLineHeight - spacing.
    // Constraint: songText + thirdLine + spacing <= widgetThickness
    // If icons/controls are taller than songText, proven: they still fit within availableThickness.
    readonly property real fontScaleFactor: {
        if (!compact.thirdLineVisible || !horizontal) return 1.0
        
        const L = baseFontMetrics.height
        const spacing = Kirigami.Units.smallSpacing
        
        var numSongLines = 0
        if (plasmoid.configuration.songTextInPanel) {
            numSongLines = 2
        }
        
        const totalTextLines = numSongLines + 1
        const needed = totalTextLines * L + spacing
        
        if (needed <= widgetThickness) return 1.0
        
        const scaleFactor = (widgetThickness - spacing) / (totalTextLines * L)
        return Math.max(0.3, Math.min(1.0, scaleFactor))
    }
    
    readonly property int availableThickness: {
        if (compact.thirdLineVisible && horizontal) {
            const thirdLineH = Math.ceil(scaledLineHeight)
            const spacing = Kirigami.Units.smallSpacing
            return Math.max(widgetThickness - thirdLineH - spacing, 16)
        }
        return widgetThickness
    }
    readonly property int controlsSize: Math.round(availableThickness * plasmoid.configuration.panelControlsSizeRatio)
    readonly property bool spaceBetweenControlsInPanel: plasmoid.configuration.spaceBetweenControlsInPanel
    readonly property int iconSize: Math.round(availableThickness * plasmoid.configuration.panelIconSizeRatio)
    readonly property int lengthMargin: Math.round((widgetThickness - Math.max(controlsSize, iconSize))) / 2
    
    // Scaled font for compact view
    readonly property font scaledFont: {
        if (fontScaleFactor >= 1.0) return baseFont
        var f = Qt.font(baseFont)
        f.pointSize = Math.max(1, Math.round(baseFont.pointSize * fontScaleFactor))
        return f
    }

    readonly property bool colorsFromAlbumCover: plasmoid.configuration.colorsFromAlbumCover
    readonly property int panelBackgroundRadius: plasmoid.configuration.panelBackgroundRadius
    readonly property bool useImageColors: panelIcon.imageReady && panelIcon.type == PanelIcon.Type.Image && colorsFromAlbumCover
    readonly property color imageColor: useImageColors ? panelIcon.imageColor : Kirigami.Theme.textColor
    readonly property color backgroundColorFromImage: Kirigami.ColorUtils.tintWithAlpha(imageColor, "black", 0.5)
    property color backgroundColor: useImageColors ? backgroundColorFromImage : "transparent"
    readonly property var backgroundColorBrightness: Kirigami.ColorUtils.brightnessForColor(backgroundColor)
    readonly property color contrastColor: backgroundColorBrightness === Kirigami.ColorUtils.Dark ? "white" : "black"
    readonly property color foregroundColorFromImage: Kirigami.ColorUtils.tintWithAlpha(imageColor, contrastColor, .6)
    property color foregroundColor: useImageColors ? foregroundColorFromImage : Kirigami.Theme.textColor

    Behavior on backgroundColor {
        ColorAnimation {
            duration: Kirigami.Units.longDuration
        }
    }

    Behavior on foregroundColor {
        ColorAnimation {
            duration: Kirigami.Units.longDuration
        }
    }

    Rectangle {
        anchors.fill: parent
        color: backgroundColor
        Item {
            width: horizontal ? parent.width : parent.width
            height: horizontal ? parent.height : parent.height
            Rectangle {
                id: progress
                color: foregroundColor
                height: horizontal ? parent.height : parent.height * (player.songPosition / player.songLength)
                width: horizontal ? parent.width * (player.songPosition / player.songLength) : parent.width
                visible: plasmoid.configuration.mediaProgressInPanel
                opacity: player.playbackStatus === Mpris.PlaybackStatus.Playing ? 0.15 : 0.07
            }
        }
    }
    layer.enabled: compact.panelBackgroundRadius > 0 && (!Qt.colorEqual(backgroundColor, "transparent") || plasmoid.configuration.mediaProgressInPanel)
    layer.effect: OpacityMask {
        maskSource: Item {
            width: compact.width
            height: compact.height
            Rectangle {
                anchors.fill: parent
                radius: compact.panelBackgroundRadius
            }
        }
    }

    MouseAreaWithWheelHandler {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        propagateComposedEvents: true

        onClicked: (mouse) => {
            switch (mouse.button) {
            case Qt.MiddleButton:
                player.playPause()
                break
            case Qt.BackButton:
                if (player.canGoPrevious) {
                    player.previous();
                }
                break
            case Qt.ForwardButton:
                if (player.canGoNext) {
                    player.next();
                }
                break
            default:
                if (mouse.modifiers & Qt.ControlModifier) {
                    if (player.canRaise) player.raise()
                } else {
                    widget.expanded = !widget.expanded;
                }
            }
        }

        onWheelUp: {
            player.changeVolume(plasmoid.configuration.volumeStep / 100, true);
        }

        onWheelDown: {
            player.changeVolume(-plasmoid.configuration.volumeStep / 100, true);
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: horizontal ? lengthMargin : 0
        anchors.rightMargin: horizontal ? lengthMargin : 0
        anchors.bottomMargin: horizontal ? 0 : lengthMargin
        anchors.topMargin: horizontal ? 0 : lengthMargin
        spacing: Kirigami.Units.smallSpacing

        GridLayout {
            id: grid

            columns: horizontal ? grid.children.length : 1
            rows: horizontal ? 1 : grid.children.length
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Layout.fillHeight: horizontal || fillAvailableSpace
            Layout.fillWidth: !horizontal || fillAvailableSpace
            Layout.maximumHeight: compact.thirdLineVisible && horizontal ? compact.availableThickness : Number.POSITIVE_INFINITY
            Layout.alignment: {
                if (fillAvailableSpace) return Qt.AlignVCenter | Qt.AlignHCenter
                if (horizontal) {
                    switch (plasmoid.configuration.contentAlignment) {
                    case 1: return Qt.AlignLeft | Qt.AlignVCenter
                    case 2: return Qt.AlignRight | Qt.AlignVCenter
                    default: return Qt.AlignHCenter | Qt.AlignVCenter
                    }
                } else {
                    switch (plasmoid.configuration.contentAlignment) {
                    case 1: return Qt.AlignTop | Qt.AlignHCenter
                    case 2: return Qt.AlignBottom | Qt.AlignHCenter
                    default: return Qt.AlignVCenter | Qt.AlignHCenter
                    }
                }
            }

            PanelIcon {
            id: panelIcon
            visible: plasmoid.configuration.iconInPanel

            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

            size: compact.iconSize
            icon: plasmoid.configuration.panelIcon
            imageUrl: player.artUrl
            imageRadius: plasmoid.configuration.albumCoverRadiusProportional ? 
                Math.round(iconSize * plasmoid.configuration.albumCoverRadius / 100) : 
                plasmoid.configuration.albumCoverRadius
            fallbackToIconWhenImageNotAvailable: plasmoid.configuration.fallbackToIconWhenImageNotAvailable
            type: {
                if (!plasmoid.configuration.useAlbumCoverAsPanelIcon) {
                    return PanelIcon.Type.Icon;
                }
                return PanelIcon.Type.Image;
            }
        }

        // This item is used to fill the available space when the song text is not enabled.
        Item {
            visible: !plasmoid.configuration.songTextInPanel && fillAvailableSpace
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        GridLayout {
            id: songGrid
            visible: plasmoid.configuration.songTextInPanel

            columns: horizontal ? songGrid.children.length : 1
            rows: horizontal ? 1 : songGrid.children.length

            readonly property int textAlignment: plasmoid.configuration.songTextAlignment
            readonly property int fxdWidth: plasmoid.configuration.songTextFixedWidth + 2 * Kirigami.Units.smallSpacing
            readonly property bool useFixedWidth: plasmoid.configuration.useSongTextFixedWidth
            readonly property int length: horizontal ? width : height

            Layout.preferredWidth: horizontal && useFixedWidth && !fillAvailableSpace ? fxdWidth : -1
            Layout.preferredHeight: !horizontal && useFixedWidth && !fillAvailableSpace ? fxdWidth : -1
            Layout.fillHeight: horizontal || fillAvailableSpace
            Layout.fillWidth: !horizontal || fillAvailableSpace
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

            Item {
                readonly property bool fill: [Qt.AlignRight, Qt.AlignCenter].includes(songGrid.textAlignment)
                Layout.fillHeight: !horizontal && fill
                Layout.fillWidth: horizontal && fill
            }

            Item {
                Layout.fillHeight: horizontal
                Layout.fillWidth: !horizontal
                Layout.preferredHeight: !horizontal ? songAndArtistText.width : null
                Layout.preferredWidth: horizontal ? songAndArtistText.width : null

                SongAndArtistText {
                    id: songAndArtistText
                    anchors.centerIn: parent

                    rotation: {
                        if (horizontal) return 0
                        if (widget.location === PlasmaCore.Types.LeftEdge) return -90
                        if (widget.location === PlasmaCore.Types.RightEdge) return 90
                    }

                    maxWidth: {
                        if (fillAvailableSpace || songGrid.useFixedWidth) {
                            return songGrid.length
                        }
                        return plasmoid.configuration.maxSongWidthInPanel
                    }
                    scrollingBehaviour: plasmoid.configuration.textScrollingBehaviour
                    scrollingSpeed: plasmoid.configuration.textScrollingSpeed
                    scrollingResetOnPause: plasmoid.configuration.textScrollingResetOnPause
                    scrollingEnabled: plasmoid.configuration.textScrollingEnabled
                    titlePosition: plasmoid.configuration.titlePosition
                    artistsPosition: plasmoid.configuration.artistsPosition
                    albumPosition: plasmoid.configuration.albumPosition
                    hideAlbumForSingles: plasmoid.configuration.compactHideAlbumForSingles
                    forcePauseScrolling: {
                        if (!plasmoid.configuration.pauseTextScrollingWhileMediaIsNotPlaying) {
                            return false
                        }
                        return player.playbackStatus !== Mpris.PlaybackStatus.Playing
                    }
                    textFont: compact.scaledFont
                    color: foregroundColor
                    title: player.title
                    artists: player.artists
                    album: player.album
                    textAlignment: songGrid.textAlignment
                    truncateStyle: plasmoid.configuration.compactTruncatedTextStyle
                    opacity: player.playbackStatus === Mpris.PlaybackStatus.Playing ? 1.0 : 0.75
                    lyricsText: lyricsManager.currentLineText
                    lyricsPosition: plasmoid.configuration.panelLyricsPosition
                }
            }

            Item {
                readonly property bool fill: [Qt.AlignLeft, Qt.AlignCenter].includes(songGrid.textAlignment)
                Layout.fillHeight: !horizontal && fill
                Layout.fillWidth: horizontal && fill
            }
        }

        GridLayout {
            columns: horizontal ? grid.children.length : 1
            rows: horizontal ? 1 : grid.children.length
            columnSpacing: spaceBetweenControlsInPanel ? Kirigami.Units.smallSpacing : 0
            rowSpacing: spaceBetweenControlsInPanel ? Kirigami.Units.smallSpacing : 0

            Layout.fillHeight: horizontal
            Layout.fillWidth: !horizontal
            Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter

            PlasmaComponents3.ToolButton {
                visible: plasmoid.configuration.skipBackwardControlInPanel
                Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter

                enabled: player.canGoPrevious
                icon.name: "media-skip-backward"
                icon.color: foregroundColor
                implicitWidth: compact.controlsSize
                implicitHeight: compact.controlsSize
                onClicked: player.previous()
            }

            PlasmaComponents3.ToolButton {
                visible: plasmoid.configuration.playPauseControlInPanel
                Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter

                enabled: player.playbackStatus === Mpris.PlaybackStatus.Playing ? player.canPause : player.canPlay
                implicitWidth: compact.controlsSize
                implicitHeight: compact.controlsSize
                icon.name: player.playbackStatus === Mpris.PlaybackStatus.Playing ? "media-playback-pause" : "media-playback-start"
                icon.color: foregroundColor
                onClicked: player.playPause()
            }

            PlasmaComponents3.ToolButton {
                visible: plasmoid.configuration.skipForwardControlInPanel
                Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter

                enabled: player.canGoNext
                implicitWidth: compact.controlsSize
                implicitHeight: compact.controlsSize
                icon.name: "media-skip-forward"
                icon.color: foregroundColor
                onClicked: player.next()
            }
        }

        }

        // Third line - independently positioned and aligned from the grid section
        ColumnLayout {
            id: thirdLineContainer
            visible: compact.thirdLineVisible && thirdLine.lineText !== ""
            spacing: 0
            Layout.fillWidth: horizontal ? (plasmoid.configuration.thirdLineWidthMode === 0) : true
            Layout.fillHeight: !horizontal ? (plasmoid.configuration.thirdLineWidthMode === 0) : false
            Layout.preferredWidth: horizontal && plasmoid.configuration.thirdLineWidthMode === 1 ? 
                Math.min(thirdLine.implicitWidth, plasmoid.configuration.thirdLineMaxWidth) : -1
            Layout.preferredHeight: !horizontal && plasmoid.configuration.thirdLineWidthMode === 1 ? 
                Math.min(thirdLine.implicitWidth, plasmoid.configuration.thirdLineMaxWidth) : -1
            Layout.maximumHeight: horizontal ? Math.ceil(compact.scaledLineHeight) : Number.POSITIVE_INFINITY
            Layout.alignment: {
                if (horizontal) {
                    switch (plasmoid.configuration.contentAlignment) {
                    case 1: return Qt.AlignLeft
                    case 2: return Qt.AlignRight
                    default: return Qt.AlignHCenter
                    }
                } else {
                    switch (plasmoid.configuration.contentAlignment) {
                    case 1: return Qt.AlignTop
                    case 2: return Qt.AlignBottom
                    default: return Qt.AlignVCenter
                    }
                }
            }
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            
            ScrollingText {
                id: thirdLine
                Layout.fillWidth: true
                
                readonly property string lineText: {
                    switch (plasmoid.configuration.thirdLineContent) {
                    case 1:
                        return player.title;
                    case 2:
                        return player.artists;
                    case 3:
                        return player.album;
                    case 4:
                        return lyricsManager.currentLineText;
                    case 5:
                        return [player.title, player.artists].filter((x) => x).join(" - ");
                    case 6:
                        return [player.title, player.artists, player.album].filter((x) => x).join(" - ");
                    default:
                        return "";
                    }
                }
                
                text: lineText
                textColor: foregroundColor
                font: compact.scaledFont
                speed: plasmoid.configuration.thirdLineScrollingSpeed
                maxWidth: plasmoid.configuration.thirdLineWidthMode === 0 ? widgetLength : plasmoid.configuration.thirdLineMaxWidth
                scrollingEnabled: plasmoid.configuration.thirdLineScrollingEnabled
                textAlignment: {
                    switch (plasmoid.configuration.thirdLineAlignment) {
                    case 0: return Qt.AlignHCenter
                    case 1: return Qt.AlignLeft
                    case 2: return Qt.AlignRight
                    default: return Qt.AlignHCenter
                    }
                }
                truncateStyle: plasmoid.configuration.compactTruncatedTextStyle
                opacity: player.playbackStatus === Mpris.PlaybackStatus.Playing ? 1.0 : 0.75
            }
        }
    }
}
