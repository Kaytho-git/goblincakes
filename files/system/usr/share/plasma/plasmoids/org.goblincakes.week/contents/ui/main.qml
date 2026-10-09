/*
    GOBLINCAKES Week – "v41" just left of the clock in the top bar.
    Plasma's clock can't show the week (Qt's date formats have no week number), so this
    sits in front of it in the same font: "v41 fre 9 okt.  21:55". ISO weeks, as in Sweden.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ISO 8601 week: the week with the year's first Thursday is week 1
    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    property int week: isoWeek(new Date())

    // Checked every minute (the week changes at midnight between Sunday and Monday)
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.week = root.isoWeek(new Date())
    }

    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    fullRepresentation: Item {
        Layout.minimumWidth: label.implicitWidth
        Layout.preferredWidth: label.implicitWidth
        Layout.fillHeight: true

        // Same font as the clock (layout.js: IBM Plex Sans 11 pt, weight 600)
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: "v" + root.week
            color: Kirigami.Theme.textColor
            font.family: "IBM Plex Sans"
            font.pointSize: 11
            font.weight: 600
        }
    }
}
