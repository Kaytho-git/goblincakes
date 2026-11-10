/*
    The calendar behind the clock box (a click on the clock): Plasma's own month view with week numbers and
    Swedish public holidays, as the top bar's clock. In its own file, loaded by a Loader: should Plasma's
    calendar module ever change name, only the popup is empty – the clock box itself still loads.
*/
import QtQuick
import org.kde.plasma.workspace.calendar as PlasmaCalendar

Item {
    PlasmaCalendar.EventPluginsManager {
        id: plugins
        enabledPlugins: ["holidaysevents"]
    }
    PlasmaCalendar.MonthView {
        anchors.fill: parent
        today: new Date()
        showWeekNumbers: true
        eventPluginsManager: plugins
    }
}
