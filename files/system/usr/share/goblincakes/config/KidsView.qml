// GOBLINCAKES Config → BARNLÄGE (13 Nov): which games and programs are in Barnläge and in what order, the PIN code
// that ends it, the parent's pictures for the backgrounds and the highest volume. 14 Nov: SPEL FRÅN RETRODECK (only
// when RetroDECK is installed, off until turned on): the parent ticks which of its games are in the "Spel" box. Backend: goblincakes-config's
// loadKids/saveKids/setKidsPin/… (kids.py). Barnläge itself: /usr/bin/goblin-kids.
import QtQuick
import QtQuick.Dialogs
import "../qml/Goblin" as G

Flickable {
    id: kidsView
    objectName: "kidsView"
    G.FastWheel { flick: kidsView }
    contentHeight: kidsCol.height + 64
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component FlatButton: G.FlatButton {}
    component FlatField: G.FlatField {}

    property var info: null
    property string status: ""
    property bool adding: false
    property string soundsTried: ""
    property string filter: ""
    readonly property var items: info ? info.items : []
    readonly property bool canStart: !!info && info.hasPin && (items.length > 0 || info.retroGames.length > 0)
    // RetroDECK's games: the search, the console and the genre, and how many rows are shown
    property string retroFilter: ""
    property string retroSystem: ""
    property string retroGenre: ""
    property bool retroOnlyChosen: false
    property int retroShown: 60
    readonly property var retroChosenKeys: info ? info.retroChosen.map(g => g.system + "/" + g.rom) : []
    readonly property var retroMatches: {
        if (!info || !info.retro)
            return [];
        const words = retroFilter.toLowerCase().split(/\s+/).filter(w => w);
        const keys = retroChosenKeys;
        return info.retroLibrary.filter(g => (!retroSystem || g.system === retroSystem)
                                         && (!retroGenre || g.genre === retroGenre)
                                         && (!retroOnlyChosen || keys.indexOf(g.system + "/" + g.rom) >= 0)
                                         && words.every(w => g.name.toLowerCase().indexOf(w) >= 0));
    }
    function retroCounts(field) {      // [{v, n}] – the consoles or genres with how many games, most first
        const counts = {};
        for (const g of (info ? info.retroLibrary : []))
            counts[g[field]] = (counts[g[field]] || 0) + 1;
        return Object.keys(counts).filter(k => k).map(k => ({ "v": k, "n": counts[k] })).sort((a, b) => b.n - a.n);
    }
    onRetroFilterChanged: retroShown = 60
    onRetroSystemChanged: retroShown = 60
    onRetroGenreChanged: retroShown = 60
    onRetroOnlyChosenChanged: retroShown = 60
    readonly property var addable: {
        if (!info || !adding)
            return [];
        const taken = items.map(i => i.kind + ":" + i.id);
        const words = filter.toLowerCase().split(/\s+/).filter(w => w);
        return info.available.filter(a => taken.indexOf(a.kind + ":" + a.id) < 0
                                     && words.every(w => a.name.toLowerCase().indexOf(w) >= 0)).slice(0, 60);
    }

    onVisibleChanged: if (visible && !info) backend.loadKids()
    Component.onCompleted: if (visible) backend.loadKids()

    Connections {
        target: backend
        function onKidsLoaded(json) {
            if (!json) {
                kidsView.status = "Kunde inte läsa barnlägets inställningar.";
                return;
            }
            kidsView.info = JSON.parse(json);
            // Name sounds missing: Cori makes them (once per set of names – not again if a voice is missing)
            const want = kidsView.items.concat(kidsView.info.retroGames).filter(i => !i.sound).map(i => i.say).join("|");
            if (want && kidsView.info.voice && want !== kidsView.soundsTried) {
                kidsView.soundsTried = want;
                backend.makeKidsSounds();
            }
        }
        function onKidsMessage(text) { kidsView.status = text; }
    }

    function change(fn) {
        const copy = JSON.parse(JSON.stringify(info));
        fn(copy);
        info = copy;
        backend.saveKids(JSON.stringify({ "items": copy.items, "volume": copy.volume, "music": copy.music,
                                          "retro": copy.retro, "retro_games": copy.retroChosen }));
    }
    function toggleRetro(g) {
        change(c => {
            const at = c.retroChosen.findIndex(x => x.system === g.system && x.rom === g.rom);
            if (at >= 0)
                c.retroChosen.splice(at, 1);
            else
                c.retroChosen.push({ "system": g.system, "rom": g.rom, "name": g.name });
        });
        retroReload.restart();   // Cori's names for the new ones – once the ticking stops
    }

    Timer { id: retroReload; interval: 2500; onTriggered: backend.loadKids() }

    FileDialog {
        id: picDialog
        title: "Bilder till barnlägets bakgrunder"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
        onAccepted: backend.addKidsPictures(JSON.stringify(selectedFiles.map(u => String(u))))
        onVisibleChanged: backend.sharpText()
    }

    component Heading: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.pixelSize: 13
        font.letterSpacing: 2
    }
    component Body: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }
    component Small: Rectangle {
        id: small
        property string text
        property bool warn: false
        signal clicked()
        width: smallText.implicitWidth + 20
        height: 26
        color: smallArea.containsMouse ? "#12203A" : "transparent"
        border.width: 1
        border.color: warn ? accent.errorBright : "#2A3852"
        Text {
            id: smallText
            anchors.centerIn: parent
            text: small.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
        MouseArea {
            id: smallArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: small.clicked()
        }
    }

    Column {
        id: kidsCol
        x: 48
        y: 32
        width: kidsView.width - 96
        spacing: 30

        Body {
            visible: !kidsView.info
            text: kidsView.status || "Läser…"
            font.pixelSize: 15
        }

        // ── the games and programs
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "SPEL OCH PROGRAM I BARNLÄGET – I DEN HÄR ORDNINGEN" }
            Body {
                width: parent.width
                text: "Bara det som ligger här går att starta i barnläget. Steam-spel startas som med goblin play. Starta ett nytt spel en gång själv först – Steam kan fråga något första gången."
            }
            Body {
                width: parent.width
                text: !kidsView.info ? "" : kidsView.info.voice === "chatterbox"
                      ? "Namnen: Cori säger spelets namn när han håller musen över det (Chatterbox gör ljuden här, en gång). Ändra vad hon säger i rutan under namnet."
                      : kidsView.info.voice === "piper"
                      ? "Namnen: Cori säger spelets namn när han håller musen över det (Piper – Chatterbox-mappen hittades inte). Ändra vad hon säger i rutan under namnet."
                      : "Namnen: ingen röst hittades. Slå på Röst i Goblin AI (Piper), eller sätt Chatterbox-mappen på plats – sedan säger Cori spelens namn."
            }
            Flow {
                width: parent.width
                spacing: 12
                Repeater {
                    model: kidsView.items
                    Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        G.Light { hovered: cardArea.containsMouse }
                        width: 168
                        height: 372
                        color: "#0E1420"
                        border.width: 1
                        border.color: "#1E2A40"
                        MouseArea { id: cardArea; anchors.fill: parent; hoverEnabled: true }
                        Rectangle {
                            id: pic
                            x: 12; y: 12
                            width: parent.width - 24; height: width * 1.5
                            color: "#12203A"
                            clip: true
                            Image {
                                anchors.fill: parent
                                visible: !!card.modelData.cover
                                source: card.modelData.cover ? "file://" + card.modelData.cover : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.height: 336
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: !card.modelData.cover
                                width: parent.width * 0.55; height: width
                                source: card.modelData.icon ? "image://icon/" + card.modelData.icon : ""
                                sourceSize.width: 128; sourceSize.height: 128
                            }
                        }
                        Text {
                            id: cardName
                            x: 12; y: pic.y + pic.height + 8
                            width: parent.width - 24
                            text: card.modelData.name
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Text {
                            x: 12; y: cardName.y + 18
                            width: parent.width - 24
                            text: card.modelData.kind === "steam"
                                  ? (card.modelData.overlay === true ? "Steam-överlägget är PÅ" : "Steam-spel")
                                  : "Program"
                            color: card.modelData.overlay === true ? accent.errorBright : "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        // What Cori says when he holds the mouse over it – ▶ plays it, the text can be changed
                        Row {
                            x: 12; y: cardName.y + 40
                            spacing: 6
                            Small {
                                text: "▶"
                                visible: !!card.modelData.sound
                                onClicked: backend.playKidsSound(card.modelData.sound)
                            }
                            Rectangle {
                                width: 144 - (card.modelData.sound ? 34 : 0); height: 26
                                color: "#0B1018"
                                border.width: 1
                                border.color: sayInput.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: sayInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: card.modelData.say || ""
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                    clip: true
                                    selectByMouse: true
                                    onEditingFinished: {
                                        const t = text.trim();
                                        if (t && t !== card.modelData.say)
                                            kidsView.change(c => { c.items[card.index].say = t; c.items[card.index].sound = ""; });
                                        backend.loadKids();
                                    }
                                }
                            }
                        }
                        Row {
                            x: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            spacing: 6
                            Small {
                                text: "◀"
                                visible: card.index > 0
                                onClicked: kidsView.change(c => c.items.splice(card.index - 1, 0, c.items.splice(card.index, 1)[0]))
                            }
                            Small {
                                text: "▶"
                                visible: card.index < kidsView.items.length - 1
                                onClicked: kidsView.change(c => c.items.splice(card.index + 1, 0, c.items.splice(card.index, 1)[0]))
                            }
                            Small {
                                text: "Ta bort"
                                onClicked: kidsView.change(c => c.items.splice(card.index, 1))
                            }
                        }
                        // Steam's overlay on: off with one click (Steam closed), or the way in Steam
                        Small {
                            anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 18 }
                            visible: card.modelData.overlay === true
                            warn: true
                            text: "Stäng av överlägget"
                            onClicked: backend.kidsOverlayOff(card.modelData.id)
                        }
                    }
                }
                Rectangle {
                    G.Light { hovered: addArea.containsMouse }
                    width: 168
                    height: 372
                    color: addArea.containsMouse ? "#0E1420" : "transparent"
                    border.width: 1
                    border.color: kidsView.adding ? accent.color : "#1E2A40"
                    Text {
                        anchors.centerIn: parent
                        text: "+ Lägg till"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { kidsView.adding = !kidsView.adding; kidsView.filter = ""; addField.text = ""; }
                    }
                }
            }

            // The list of everything that can be added
            Column {
                visible: kidsView.adding
                width: parent.width
                spacing: 8
                FlatField {
                    id: addField
                    width: Math.min(420, parent.width)
                    hint: "Sök bland spel och program…"
                    onTextChanged: kidsView.filter = text
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: kidsView.addable
                        Rectangle {
                            id: row
                            required property var modelData
                            width: Math.min(360, (kidsCol.width - 12) / 3)
                            height: 44
                            color: rowArea.containsMouse ? "#12203A" : "#0E1420"
                            border.width: 1
                            border.color: "#1E2A40"
                            Image {
                                id: rowIcon
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24
                                visible: row.modelData.kind === "app"
                                source: row.modelData.icon ? "image://icon/" + row.modelData.icon : ""
                                sourceSize.width: 48; sourceSize.height: 48
                            }
                            Text {
                                x: 44
                                width: parent.width - 54
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name + "  <font color='#8B98AD'>" + (row.modelData.kind === "steam" ? "Steam-spel" : (row.modelData.group || "Program")) + "</font>"
                                textFormat: Text.StyledText
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = row.modelData;
                                    kidsView.change(c => c.items.push({ "kind": a.kind, "id": a.id, "name": a.name, "icon": a.icon || "", "cover": "" }));
                                    backend.loadKids();   // the cover picture and the overlay
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── RetroDECK's games: only when RetroDECK is installed, and only the games the parent ticks
        Column {
            visible: !!kidsView.info && kidsView.info.retrodeck
            width: parent.width
            spacing: 12
            Heading { text: "SPEL FRÅN RETRODECK" }
            Body {
                width: parent.width
                text: "RetroDECK är installerat. Vill du kan några av dess spel finnas i barnläget: då får barnläget en ruta Spel med de spel du bockar i här. "
                      + "De spelas med handkontroll, och Start+Select två gånger tar barnet tillbaka till barnläget. RetroArchs meny är avstängd medan barnläget kör ett spel – RetroDECK:s egna inställningar ändras inte."
            }
            Row {
                spacing: 8
                Repeater {
                    model: [{ v: true, t: "Visa valda spel" }, { v: false, t: "Inga spel från RetroDECK" }]
                    Rectangle {
                        id: rd
                        required property var modelData
                        G.Light { hovered: rdArea.containsMouse }
                        readonly property bool on: !!kidsView.info && kidsView.info.retro === modelData.v
                        width: rdText.implicitWidth + 36
                        height: 44
                        color: on ? "#12203A" : rdArea.containsMouse ? "#0E1420" : "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? accent.color : "#1E2A40"
                        Text {
                            id: rdText
                            anchors.centerIn: parent
                            text: rd.modelData.t
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: rdArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { kidsView.change(c => c.retro = rd.modelData.v); backend.loadKids(); }
                        }
                    }
                }
            }
            Column {
                visible: !!kidsView.info && kidsView.info.retro
                width: parent.width
                spacing: 10
                Body {
                    width: parent.width
                    readonly property int chosen: kidsView.info ? kidsView.info.retroChosen.length : 0
                    readonly property int found: kidsView.info ? kidsView.info.retroGames.length : 0
                    text: !kidsView.info ? "" : !kidsView.info.retroLibrary.length
                          ? "Hittar inga spel i RetroDECK:s spelmapp just nu – är disken med spelen inkopplad?"
                          : (chosen ? chosen + (chosen === 1 ? " spel valt" : " spel valda") : "Inga spel valda än – bocka i dem som ska synas.")
                            + (found < chosen ? " " + (chosen - found) + " av dem hittas inte just nu (är disken inkopplad?)." : "")
                            + "  " + kidsView.info.retroLibrary.length + " spel i RetroDECK."
                    color: kidsView.info && kidsView.info.retroGames.length < kidsView.info.retroChosen.length ? accent.errorBright : "#8B98AD"
                }
                FlatField {
                    id: retroField
                    width: Math.min(420, parent.width)
                    hint: "Sök bland RetroDECK:s spel…"
                    onTextChanged: kidsView.retroFilter = text
                }
                // The console, the genre and "only the chosen" – a click again turns it off
                Flow {
                    width: parent.width
                    spacing: 6
                    Small {
                        text: "Bara valda (" + kidsView.retroChosenKeys.length + ")"
                        color: kidsView.retroOnlyChosen ? "#12203A" : "transparent"
                        border.color: kidsView.retroOnlyChosen ? accent.color : "#2A3852"
                        onClicked: kidsView.retroOnlyChosen = !kidsView.retroOnlyChosen
                    }
                    Item { width: 12; height: 26 }
                    Repeater {
                        model: kidsView.info && kidsView.info.retro ? kidsView.retroCounts("system") : []
                        Small {
                            required property var modelData
                            readonly property bool on: kidsView.retroSystem === modelData.v
                            text: modelData.v.toUpperCase() + " (" + modelData.n + ")"
                            color: on ? "#12203A" : "transparent"
                            border.color: on ? accent.color : "#2A3852"
                            onClicked: kidsView.retroSystem = on ? "" : modelData.v
                        }
                    }
                    Item { width: 12; height: 26 }
                    Repeater {
                        model: kidsView.info && kidsView.info.retro ? kidsView.retroCounts("genre") : []
                        Small {
                            required property var modelData
                            readonly property bool on: kidsView.retroGenre === modelData.v
                            text: modelData.v + " (" + modelData.n + ")"
                            color: on ? "#12203A" : "transparent"
                            border.color: on ? accent.color : "#2A3852"
                            onClicked: kidsView.retroGenre = on ? "" : modelData.v
                        }
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: kidsView.retroMatches.slice(0, kidsView.retroShown)
                        Rectangle {
                            id: rrow
                            required property var modelData
                            readonly property bool on: kidsView.retroChosenKeys.indexOf(modelData.system + "/" + modelData.rom) >= 0
                            width: Math.min(360, (kidsCol.width - 12) / 3)
                            height: 56
                            color: rrowArea.containsMouse ? "#12203A" : "#0E1420"
                            border.width: 1
                            border.color: on ? accent.color : "#1E2A40"
                            G.CheckSquare {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                checked: rrow.on
                            }
                            Rectangle {
                                id: rcover
                                x: 42
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44; height: 44
                                color: "#12203A"
                                Image {
                                    anchors.fill: parent
                                    source: rrow.modelData.cover ? "file://" + rrow.modelData.cover : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize.height: 88
                                }
                            }
                            Column {
                                x: rcover.x + rcover.width + 10
                                width: parent.width - x - 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: rrow.modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: [rrow.modelData.system.toUpperCase(), rrow.modelData.genre,
                                           rrow.modelData.players ? rrow.modelData.players + " spelare" : ""].filter(t => t).join(" · ")
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: rrowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: kidsView.toggleRetro(rrow.modelData)
                            }
                        }
                    }
                }
                Small {
                    visible: kidsView.retroMatches.length > kidsView.retroShown
                    text: "Visa fler (" + (kidsView.retroMatches.length - kidsView.retroShown) + " till)"
                    onClicked: kidsView.retroShown += 60
                }
            }
        }

        // ── the PIN code
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "PIN-KOD – AVSLUTAR BARNLÄGET (X:ET UPPE TILL HÖGER)" }
            Body {
                width: parent.width
                text: kidsView.info && kidsView.info.hasPin
                      ? "En PIN-kod är sparad. Skriv en ny här för att byta."
                      : "Ingen PIN-kod ännu – barnläget startar inte utan. 4–8 siffror."
                color: kidsView.info && kidsView.info.hasPin ? "#8B98AD" : accent.errorBright
            }
            Row {
                spacing: 12
                FlatField {
                    id: pinField
                    width: 220
                    hint: "Ny PIN-kod"
                    echoMode: TextInput.Password
                    validator: RegularExpressionValidator { regularExpression: /\d{0,8}/ }
                }
                FlatButton {
                    text: "Spara PIN-kod"
                    enabledState: pinField.text.length >= 4
                    onClicked: {
                        if (backend.setKidsPin(pinField.text)) {
                            pinField.text = "";
                            kidsView.info = Object.assign({}, kidsView.info, { "hasPin": true });
                        }
                    }
                }
            }
        }

        // ── the backgrounds
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "BAKGRUNDER – HAN VÄLJER SJÄLV MED BILDKNAPPEN UPPE TILL VÄNSTER" }
            Body {
                width: parent.width
                text: "Natthimmel, Havet, Regnbåge och Solnedgång finns alltid. Hans teckningar från Tux Paint kommer med av sig själva"
                      + (kidsView.info && kidsView.info.drawings ? " (" + kidsView.info.drawings + " nu)." : ".")
                      + " Här lägger du till egna bilder."
            }
            Flow {
                width: parent.width
                spacing: 12
                Repeater {
                    model: kidsView.info ? kidsView.info.pictures : []
                    Rectangle {
                        id: picCard
                        required property var modelData
                        width: 200; height: 124
                        color: "#0E1420"
                        border.width: 1
                        border.color: "#1E2A40"
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + picCard.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 400
                        }
                        Small {
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            text: "Ta bort"
                            color: "#0B1018"
                            onClicked: backend.removeKidsPicture(picCard.modelData)
                        }
                    }
                }
                Rectangle {
                    G.Light { hovered: picAddArea.containsMouse }
                    width: 200; height: 124
                    color: picAddArea.containsMouse ? "#0E1420" : "transparent"
                    border.width: 1
                    border.color: "#1E2A40"
                    Text {
                        anchors.centerIn: parent
                        text: "+ Lägg till bilder"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: picAddArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picDialog.open()
                    }
                }
            }
        }

        // ── GOBLINCAKES' songs: the music picture last among the games
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "MUSIK – GOBLINCAKES LÅTAR" }
            Body {
                width: parent.width
                text: !kidsView.info ? "" : !kidsView.info.songs.length ? "Inga låtar hittades."
                      : "En musikbild sist bland spelen: han trycker ▶ Start och ■ Stopp på låtarna ("
                        + kidsView.info.songs.map(s => s.name).join(", ") + "). Musiken stannar när ett spel startar. Nya GOBLINCAKES-låtar kommer med av sig själva."
            }
            Row {
                spacing: 8
                Repeater {
                    model: [{ v: true, t: "Med musikbilden" }, { v: false, t: "Utan" }]
                    Rectangle {
                        id: mus
                        required property var modelData
                        G.Light { hovered: musArea.containsMouse }
                        readonly property bool on: !!kidsView.info && kidsView.info.music === modelData.v
                        width: musText.implicitWidth + 36
                        height: 44
                        color: on ? "#12203A" : musArea.containsMouse ? "#0E1420" : "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? accent.color : "#1E2A40"
                        Text {
                            id: musText
                            anchors.centerIn: parent
                            text: mus.modelData.t
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: musArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: kidsView.change(c => c.music = mus.modelData.v)
                        }
                    }
                }
            }
        }

        // ── the volume
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "HÖGSTA LJUDNIVÅ I BARNLÄGET (HUVUDVOLYMEN)" }
            Row {
                spacing: 8
                Repeater {
                    model: [{ v: 0, t: "Ingen gräns" }, { v: 40, t: "40 %" }, { v: 60, t: "60 %" }, { v: 80, t: "80 %" }]
                    Rectangle {
                        id: vol
                        required property var modelData
                        G.Light { hovered: volArea.containsMouse }
                        readonly property bool on: !!kidsView.info && kidsView.info.volume === modelData.v
                        width: volText.implicitWidth + 36
                        height: 44
                        color: on ? "#12203A" : volArea.containsMouse ? "#0E1420" : "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? accent.color : "#1E2A40"
                        Text {
                            id: volText
                            anchors.centerIn: parent
                            text: vol.modelData.t
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: volArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: kidsView.change(c => c.volume = vol.modelData.v)
                        }
                    }
                }
            }
        }

        // ── good to know
        Column {
            visible: !!kidsView.info
            width: parent.width
            spacing: 12
            Heading { text: "BRA ATT VETA" }
            Body {
                width: parent.width
                text: "Medan barnläget är på syns bara huvudskärmen (de andra täcks), dina fönster göms och kommer tillbaka efteråt, "
                      + "kortkommandona (Meta, Alt+Tab, Alt+F4 …), notiserna och strömknappen är avstängda, och MangoHud döljs i spelen. "
                      + "Steam-överlägget stängs av per spel: här ovan när Steam är stängt, eller i Steam → spelet → Egenskaper → Allmänt.\n"
                      + "Glömt PIN-koden? Ctrl+Alt+F3, logga in och skriv goblin barn stopp – sedan Ctrl+Alt+F2 (eller F1) tillbaka."
            }
        }
    }
}
