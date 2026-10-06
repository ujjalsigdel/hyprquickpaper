import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "hyprquickpaper-settings"

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string active_layout: "shell-classic.qml"
            property string border_color: "#C27B63"
        }
    }

    readonly property var layouts: [
        { file: "shell-classic.qml",                    name: "Classic",                shot: "classic.jpg" },
        { file: "shell-bottom-dock.qml",                name: "Bottom Dock",            shot: "bottom-dock.jpg" },
        { file: "shell-coverflow.qml",                  name: "Coverflow",              shot: "coverflow.jpg" },
        { file: "shell-coverflow-clear.qml",            name: "Coverflow Clear",        shot: "coverflow-clear.jpg" },
        { file: "shell-coverflow-minimal.qml",          name: "Coverflow Minimal",      shot: "coverflow-minimal.jpg" },
        { file: "shell-floating.qml",                   name: "Floating",               shot: "floating.jpg" },
        { file: "shell-floating-center-reflection.qml", name: "Floating C-Reflection",  shot: "floating-center-reflection.jpg" },
        { file: "shell-floating-clean.qml",             name: "Floating Clean",         shot: "floating-clean.jpg" },
        { file: "shell-floating-clear.qml",             name: "Floating Clear",         shot: "floating-clear.jpg" },
        { file: "shell-floating-clear-clean.qml",       name: "Floating Clear Clean",   shot: "floating-clear-clean.jpg" },
        { file: "shell-floating-minimal.qml",           name: "Floating Minimal",       shot: "floating-minimal.jpg" },
        { file: "shell-floating-minimal-clean.qml",     name: "Floating Minimal Clean", shot: "floating-minimal-clean.jpg" },
        { file: "shell-grid-view.qml",                  name: "Grid View",              shot: "grid-view.jpg" },
        { file: "shell-hexcomb.qml",                    name: "Hexacomb",               shot: "hexcomb.jpg" }
    ]

    function applyLayout(fileName) {
        Quickshell.execDetached([
            "bash",
            Quickshell.shellPath("set-layout.sh"),
            Quickshell.shellDir,
            fileName
        ])
        Qt.quit()
    }

    // Pre-select the currently active layout once config.json has been
    // read. Small delay so the JsonAdapter has definitely populated.
    Timer {
        interval: 60
        running: true
        repeat: false
        onTriggered: {
            for (let i = 0; i < main.layouts.length; i++) {
                if (main.layouts[i].file === configs.active_layout) {
                    grid.currentIndex = i
                    break
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#cc05070a"
    }

    Column {
        id: header
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(40, parent.height * 0.05)
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CHOOSE A LAYOUT"
            color: "#f2f2f2"
            font.pixelSize: 34
            font.letterSpacing: 10
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "hjkl / arrows to navigate  ·  Enter to apply  ·  Esc to close"
            color: "#8899a3"
            font.pixelSize: 13
            font.letterSpacing: 2
        }
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 32
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: parent.width * 0.06
        anchors.rightMargin: parent.width * 0.06
        anchors.bottomMargin: 40
        clip: true

        cellWidth: width / 4
        cellHeight: cellWidth * 0.65

        model: main.layouts
        focus: true
        keyNavigationWraps: true
        highlightFollowsCurrentItem: true

        // If the currently-focused card is off-screen (happens after
        // arrow-key navigation), scroll it into view.
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, GridView.Contain)
        }

        delegate: Item {
            id: cell
            width: grid.cellWidth
            height: grid.cellHeight
            property bool isActive: modelData.file === configs.active_layout
            property bool isFocused: index === grid.currentIndex

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: 12
                color: "#14171d"
                // Border priority: active > focused > default.
                border.width: isFocused ? 3 : (isActive ? 2 : 1)
                border.color: isFocused
                ? (configs.border_color || "#C27B63")
                : (isActive ? "#8899a3" : "#33ffffff")
                clip: true

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: (isActive || isFocused) ? 3 : 0
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    source: "file://" + Quickshell.shellPath("assets/screenshots/" + modelData.shot)

                    // Decode at display size instead of native size. 1.5x covers
                    // HiDPI screens without wasting decode work on 4K screenshots.
                    sourceSize.width: grid.cellWidth * 1.5
                    sourceSize.height: grid.cellHeight * 1.5

                    Text {
                        anchors.centerIn: parent
                        text: thumb.status === Image.Error ? "No screenshot" : ""
                        color: "#8899a3"
                        font.pixelSize: 12
                        visible: thumb.status === Image.Error
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 38
                    color: "#cc000000"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: isFocused
                        ? (configs.border_color || "#f2f2f2")
                        : "#f2f2f2"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    grid.currentIndex = index
                    main.applyLayout(modelData.file)
                }
            }
        }

        Keys.onPressed: function(event) {
            // hjkl — arrow keys are handled by GridView natively.
            switch (event.key) {
                case Qt.Key_H:
                    moveCurrentIndexLeft()
                    event.accepted = true
                    break
                case Qt.Key_L:
                    moveCurrentIndexRight()
                    event.accepted = true
                    break
                case Qt.Key_K:
                    moveCurrentIndexUp()
                    event.accepted = true
                    break
                case Qt.Key_J:
                    moveCurrentIndexDown()
                    event.accepted = true
                    break
                case Qt.Key_Escape:
                    Qt.quit()
                    event.accepted = true
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    if (currentIndex >= 0 && currentIndex < main.layouts.length)
                        main.applyLayout(main.layouts[currentIndex].file)
                    event.accepted = true
                    break
                default:
                    // Let GridView handle arrows and anything else.
                    break
            }
        }
    }
}
