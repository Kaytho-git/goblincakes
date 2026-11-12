// A program's two letters in a square, when it has no icon (Config, Avinstallera – P16, 12 Nov)
import QtQuick

Rectangle {
    id: mono
    property string name
    width: 48
    height: 48
    color: "#12203A"
    border.width: 1
    border.color: "#1E2A40"
    Light {}
    Text {
        anchors.centerIn: parent
        text: {
            const words = mono.name.replace(/[^A-Za-z0-9 .-]/g, "").split(/[ .-]+/).filter(w => w.length);
            return (words.length > 1 ? words[0][0] + words[1][0] : mono.name.slice(0, 2)).toUpperCase();
        }
        color: "#E6ECF5"
        font.family: "Chakra Petch"
        font.weight: Font.Bold
        font.pixelSize: 18
    }
}
