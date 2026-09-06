import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"
    property int speed: 5000
    property string currentImagePath: ""
    property bool bgToggle: false
    property string searchQuery: ""
    property date currentDateTime: new Date()

    // Load custom  font file directly
    FontLoader {
        id: customDisplayFont
        source: Quickshell.shellPath("./assets/fonts/anurati-regular.otf")
    }

    // -----------------------------------------------------
    // COVERFLOW TUNABLES
    // -----------------------------------------------------
    property real cardW: 190
    property real cardH: 340
    property real centerScale: 1.15
    property real edgeScale: 0.55
    property real gapPx: 20  // small, clearly visible constant gap between EVERY pair of cards

    property real skewFactor: -0.18

    function scaleForOffset(offset) {
        const a = Math.abs(offset);
        if (a === 0) return centerScale;
        if (a === 1) return 0.9;
        if (a === 2) return 0.75;
        if (a === 3) return 0.7;
        if (a === 4) return 0.62;
        return edgeScale;
    }

    function stepBetween(o) {
        const sA = scaleForOffset(o)
        const sB = scaleForOffset(o + 1)
        const widthTerm = (sA + sB) * cardW / 2
        const shearTerm = Math.abs(skewFactor) * cardH * Math.abs(sA - sB) / 2
        return widthTerm + shearTerm + gapPx
    }

    function cumulativeOffset(n) {
        const steps = Math.abs(n)
        let sum = 0
        for (let i = 0; i < steps; i++) {
            sum += stepBetween(i)
        }
        return n < 0 ? -sum : sum
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir]);
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    FileView {
        id: activeWallpaperFile
        path: Quickshell.env("HOME") + "/.cache/hyprquickpaper/current_wallpaper"
        watchChanges: false
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path.replace("~", Quickshell.env("HOME"))
        showDirs: false
        nameFilters: searchQuery.length > 0
        ? ["*" + searchQuery + "*.png",
        "*" + searchQuery + "*.jpg",
        "*" + searchQuery + "*.jpeg"]
        : ["*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentDateTime = new Date()
    }

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(pathView.currentIndex, "fileName")
        const fullPath = "file://" + configs.cache_path.replace("~", Quickshell.env("HOME")) + fileName
        currentImagePath = fullPath
        if (!bgToggle) {
            bgImageB.source = fullPath
            bgToggle = true
        } else {
            bgImageA.source = fullPath
            bgToggle = false
        }
    }

    // -----------------------------------------------------
    // CRISP, FULL-QUALITY BACKGROUND (matches reference: wallpaper
    // shown clearly, only a soft fade at the very bottom edge so the
    // dock stays legible — no blur, no desaturation, no glow blob)
    // -----------------------------------------------------
    Item {
        id: backgroundLayer
        anchors.fill: parent

        Image {
            id: bgImageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            // Was "visible: false" in the previous version — an
            // invisible Image can't be captured as a texture source,
            // so nothing actually displayed: the panel just showed
            // transparent (whatever sits behind it) with only the old
            // glow/vignette layers drawn on top. That's what looked
            // like "a white circle with a bit of light."
            visible: true
            opacity: bgToggle ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        }

        Image {
            id: bgImageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            visible: true
            opacity: bgToggle ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        }

        // Soft fade at just the bottom edge, behind the dock, so cards
        // stay readable against busy wallpapers — everything above
        // that stays fully clear and undimmed, matching the reference.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.72; color: "#00000000" }
                GradientStop { position: 1.0; color: "#99000000" }
            }
        }
    }

    MouseArea {
        id: dismissSearchArea
        anchors.fill: parent
        z: -1
        enabled: searchInput.activeFocus
        onClicked: {
            searchInput.text = "";
            pathView.forceActiveFocus();
        }
    }

    // -----------------------------------------------------
    // FLAT ROW OF UNIFORMLY-SHEARED (PARALLELOGRAM) CARDS
    // -----------------------------------------------------
    PathView {
        id: pathView
        anchors.fill: parent
        focus: true
        interactive: false

        model: folderModel
        pathItemCount: 11
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5

        onCurrentIndexChanged: updateBackground()

        Timer {
            id: initTimer
            interval: 50
            repeat: false
            onTriggered: {
                if (folderModel.count === 0) return

                let rawText = activeWallpaperFile.text() ? activeWallpaperFile.text() : ""
                let activePath = rawText.trim()
                let matchedIndex = -1

                if (activePath.length > 0) {
                    for (let i = 0; i < folderModel.count; i++) {
                        let itemPath = folderModel.get(i, "filePath")
                        if (itemPath === activePath) {
                            matchedIndex = i
                            break
                        }
                    }
                }

                if (matchedIndex === -1) {
                    matchedIndex = Math.floor(folderModel.count / 2)
                }

                pathView.currentIndex = matchedIndex
                updateBackground()
            }
        }

        Connections {
            target: folderModel
            function onCountChanged() {
                initTimer.restart()
            }
        }

        function activateCurrent() {
            const path = folderModel.get(pathView.currentIndex, "filePath");
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            Qt.quit();
        }

        path: Path {
            startX: main.width / 2 + main.cumulativeOffset(-5)
            startY: main.height / 2
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(-5) }
            PathAttribute { name: "itemOpacity"; value: 0.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathPercent { value: 0.0 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(-4); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(-4) }
            PathAttribute { name: "itemOpacity"; value: 0.4 }
            PathAttribute { name: "itemZ"; value: 20 }
            PathPercent { value: 0.1 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(-3); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(-3) }
            PathAttribute { name: "itemOpacity"; value: 0.65 }
            PathAttribute { name: "itemZ"; value: 40 }
            PathPercent { value: 0.2 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(-2); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(-2) }
            PathAttribute { name: "itemOpacity"; value: 0.85 }
            PathAttribute { name: "itemZ"; value: 60 }
            PathPercent { value: 0.3 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(-1); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(-1) }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 80 }
            PathPercent { value: 0.4 }

            PathLine { x: main.width / 2; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(0) }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 100 }
            PathPercent { value: 0.5 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(1); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(1) }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 80 }
            PathPercent { value: 0.6 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(2); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(2) }
            PathAttribute { name: "itemOpacity"; value: 0.85 }
            PathAttribute { name: "itemZ"; value: 60 }
            PathPercent { value: 0.7 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(3); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(3) }
            PathAttribute { name: "itemOpacity"; value: 0.65 }
            PathAttribute { name: "itemZ"; value: 40 }
            PathPercent { value: 0.8 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(4); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(4) }
            PathAttribute { name: "itemOpacity"; value: 0.4 }
            PathAttribute { name: "itemZ"; value: 20 }
            PathPercent { value: 0.9 }

            PathLine { x: main.width / 2 + main.cumulativeOffset(5); y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: main.scaleForOffset(5) }
            PathAttribute { name: "itemOpacity"; value: 0.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathPercent { value: 1.0 }
        }

        delegate: Item {
            id: delegateItem
            width: cardW
            height: cardH

            scale: PathView.itemScale
            opacity: PathView.itemOpacity
            z: PathView.itemZ

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, main.skewFactor, 0, -main.skewFactor * main.cardH / 2,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
            }

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "#1e1e2e"
                clip: true
                border.width: PathView.isCurrentItem ? 3 : 1
                border.color: PathView.isCurrentItem ? configs.border_color : "#22ffffff"

                Text {
                    id: alt
                    text: "Loading..."
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 14
                }

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" + configs.cache_path.replace("~", Quickshell.env("HOME")) + fileName

                    sourceSize.width: width
                    sourceSize.height: height

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            let s = img.source;
                            img.source = "";
                            img.source = s;
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching";
                            retryTimer.start();
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pathView.forceActiveFocus();
                    if (pathView.currentIndex === index) {
                        pathView.activateCurrent();
                    } else {
                        pathView.currentIndex = index;
                    }
                }
            }
        }

        Keys.onPressed: function (event) {
            const step = 1;
            const big = configs.number_of_pictures > 0 ? configs.number_of_pictures : 5;

            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                pathView.incrementCurrentIndex();
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                pathView.decrementCurrentIndex();
            } else if (event.key === Qt.Key_U) {
                for (let i = 0; i < big; i++) pathView.incrementCurrentIndex();
            } else if (event.key === Qt.Key_D) {
                for (let i = 0; i < big; i++) pathView.decrementCurrentIndex();
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                pathView.activateCurrent();
            } else if (event.key === Qt.Key_Slash) {
                searchInput.forceActiveFocus();
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    // -----------------------------------------------------
    // DATE / TIME + SEARCH HEADER
    // -----------------------------------------------------
    Column {
        id: headerColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60
        spacing: 6
        z: 200

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(currentDateTime, "dddd").toUpperCase()
            color: "#f2f2f2"
            font.pixelSize: 60
            font.letterSpacing: 12
            font.family: customDisplayFont.name
            font.capitalization: Font.AllUppercase
            style: Text.Raised
            styleColor: "#40000000"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(currentDateTime, "dd MMM yyyy").toUpperCase()
            color: "#cfcfcf"
            font.pixelSize: 16
            font.letterSpacing: 4
            font.family: "sans-serif"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "- " + Qt.formatDateTime(currentDateTime, "hh:mm AP") + " -"
            color: "#cfcfcf"
            font.pixelSize: 14
            font.letterSpacing: 3
            font.family: "sans-serif"
        }

        Item { width: 1; height: 14 }

        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: 40
            radius: 20
            color: "#33000000"
            border.width: 1
            border.color: "#33ffffff"

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                color: "#f2f2f2"
                font.pixelSize: 14
                clip: true
                selectByMouse: true

                onTextChanged: searchQuery = text

                Keys.onEscapePressed: {
                    searchInput.text = "";
                    pathView.forceActiveFocus();
                }
                Keys.onReturnPressed: pathView.forceActiveFocus()
                Keys.onEnterPressed: pathView.forceActiveFocus()
                Keys.onDownPressed: pathView.forceActiveFocus()
                Keys.onTabPressed: pathView.forceActiveFocus()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search wallpapers..."
                    color: "#88ffffff"
                    font.pixelSize: 14
                    visible: searchInput.text.length === 0
                }
            }
        }
    }
}
