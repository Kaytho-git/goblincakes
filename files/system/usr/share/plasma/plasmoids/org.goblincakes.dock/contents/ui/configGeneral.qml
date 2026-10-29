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
    property real cfg_scale: 1.0
    property alias cfg_zoom: zoom.checked
    property alias cfg_zoomFactor: factor.value
    property alias cfg_zoomRange: range.value

    Kirigami.FormLayout {
        // 1,0 = like the old dock; − and + in steps of 0,1 (the value is tenths; note the Slider
        // below has id `factor`, so that name can't be used in here)
        QQC2.SpinBox {
            id: scaleBox
            Kirigami.FormData.label: "Storlek:"
            value: Math.round((isNaN(cfg_scale) ? 1 : cfg_scale) * 10)
            from: 5; to: 20; stepSize: 1
            editable: true
            textFromValue: v => (v / 10).toFixed(1).replace(".", ",")
            valueFromText: text => {
                const n = parseFloat(String(text).replace(",", "."));
                return isNaN(n) ? value : Math.round(n * 10);
            }
            onValueModified: cfg_scale = value / 10
        }
        QQC2.CheckBox {
            id: zoom
            Kirigami.FormData.label: "Våg:"
            text: "Ikonerna växer under pekaren"
        }
        RowLayout {
            Kirigami.FormData.label: "Förstoring:"
            enabled: zoom.checked
            QQC2.Slider {
                id: factor
                from: 1.0; to: 1.5; stepSize: 0.1
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
            text: "Storlek 1,0 = som gamla dockan. Panelen måste vara minst så hög som dockan blir (48 px × storleken), annars begränsas den."
        }
    }
}
