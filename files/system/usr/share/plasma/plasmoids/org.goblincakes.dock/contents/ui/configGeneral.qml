/*
    Plasma's own settings page for the dock (right click → Konfigurera). The size is the
    panel's thickness (drag the panel's edge in edit mode); everything in the dock follows it.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_style: style.currentIndex
    property alias cfg_zoom: zoom.checked
    property alias cfg_zoomFactor: factor.value
    property alias cfg_zoomRange: range.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: zoom
            Kirigami.FormData.label: "Våg:"
            text: "Ikonerna växer under pekaren"
        }
        QQC2.ComboBox {
            id: style
            Kirigami.FormData.label: "Ramen:"
            enabled: zoom.checked
            model: ["Växer med vågen", "Står still (luftig)"]
        }
        RowLayout {
            Kirigami.FormData.label: "Förstoring:"
            enabled: zoom.checked
            QQC2.Slider {
                id: factor
                from: 1.2; to: 2.0; stepSize: 0.1
            }
            QQC2.Label { text: factor.value.toFixed(1) + "×" }
        }
        RowLayout {
            Kirigami.FormData.label: "Vågens bredd:"
            enabled: zoom.checked
            QQC2.Slider {
                id: range
                from: 1.5; to: 4.0; stepSize: 0.5
            }
            QQC2.Label { text: range.value.toFixed(1) + " ikoner åt varje håll" }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            text: "Storleken = panelens höjd: dra i panelens kant i redigeringsläget, ikonerna följer med."
        }
    }
}
