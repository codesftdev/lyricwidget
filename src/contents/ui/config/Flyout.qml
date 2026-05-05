import "../components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM


KCM.SimpleKCM {
    id: flyoutConfigPage
    Layout.preferredWidth: form.implicitWidth;

    property alias cfg_showLyrics: showLyrics.checked
    property alias cfg_lyricsScrollingSpeed: lyricsScrollingSpeed.value
    property alias cfg_lyricsAlignment: lyricsAlignment.value

    Kirigami.FormLayout {
        id: form

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Lyrics")
        }

        CheckBox {
            id: showLyrics
            Kirigami.FormData.label: i18n("Show live lyrics")
        }

        ButtonGroup {
            id: lyricsAlignment
            property int value: Qt.AlignHCenter
        }

        RadioButton {
            Kirigami.FormData.label: i18n("Lyrics alignment:")
            text: i18n("Left")
            enabled: showLyrics.checked
            checked: lyricsAlignment.value == Qt.AlignLeft
            onCheckedChanged: () => {
                if (checked) {
                    lyricsAlignment.value = Qt.AlignLeft
                }
            }
            ButtonGroup.group: lyricsAlignment
        }

        RadioButton {
            text: i18n("Center")
            enabled: showLyrics.checked
            checked: lyricsAlignment.value == Qt.AlignHCenter
            onCheckedChanged: () => {
                if (checked) {
                    lyricsAlignment.value = Qt.AlignHCenter
                }
            }
            ButtonGroup.group: lyricsAlignment
        }

        RadioButton {
            text: i18n("Right")
            enabled: showLyrics.checked
            checked: lyricsAlignment.value == Qt.AlignRight
            onCheckedChanged: () => {
                if (checked) {
                    lyricsAlignment.value = Qt.AlignRight
                }
            }
            ButtonGroup.group: lyricsAlignment
        }

        Slider {
            Layout.preferredWidth: 10 * Kirigami.Units.gridUnit
            id: lyricsScrollingSpeed
            from: 1
            to: 10
            stepSize: 1
            enabled: showLyrics.checked
            Kirigami.FormData.label: i18n("Lyrics scrolling speed:")
        }
    }
}
