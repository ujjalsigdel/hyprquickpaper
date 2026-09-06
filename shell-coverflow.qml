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
        path: Quickshell.env("HOME") + "/.cache/ml4w/hyprland-dotfiles/current_wallpaper"
        watchChanges: false
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path.replace("~", Quickshell.env("HOME"))
        showDirs: false
        nameFilters: ["*.png", "*.jpg"]
        sortField: FolderListModel.Name
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
    // BLURRED / DARKENED BACKGROUND OF THE SELECTED WALLPAPER
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
            visible: false
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
            visible: false
            opacity: bgToggle ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        }

        MultiEffect {
            anchors.fill: parent
            source: bgImageA
            opacity: bgImageA.opacity
            blurEnabled: true
            blur: 1.0
            blurMax: 72
            brightness: -0.25
            saturation: 0.05
        }

        MultiEffect {
            anchors.fill: parent
            source: bgImageB
            opacity: bgImageB.opacity
            blurEnabled: true
            blur: 1.0
            blurMax: 72
            brightness: -0.25
            saturation: 0.05
        }

        // Soft colored glow behind the center card, tinted with the accent color
        Rectangle {
            width: parent.width * 0.5
            height: parent.height * 0.9
            anchors.centerIn: parent
            radius: width * 0.5
            color: configs.border_color
            opacity: 0.18
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 90
            }
        }

        // Vignette / darken so the cards stay readable
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#33000000" }
                GradientStop { position: 0.5; color: "#00000000" }
                GradientStop { position: 1.0; color: "#AA000000" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#77000000" }
                GradientStop { position: 0.5; color: "#00000000" }
                GradientStop { position: 1.0; color: "#77000000" }
            }
        }
    }

    // -----------------------------------------------------
    // CLEAN 3D COVER FLOW PATHVIEW
    // -----------------------------------------------------
    PathView {
        id: pathView
        anchors.fill: parent
        focus: true

        model: folderModel
        pathItemCount: 13
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

        // Evenly spaced percent stops (0.125 apart) with x staying linear
        // in percent, so every card sits an equal pixel distance from its
        // neighbors — no clustering, no overlap, just a smooth symmetric
        // falloff in scale/angle/opacity toward the edges.
        path: Path {
            startX: -0.15 * main.width
            startY: main.height / 2
            PathAttribute { name: "itemScale"; value: 0.35 }
            PathAttribute { name: "itemAngle"; value: 38 }
            PathAttribute { name: "itemOpacity"; value: 0.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathPercent { value: 0.0 }

            PathLine { x: main.width * 0.0125; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.45 }
            PathAttribute { name: "itemAngle"; value: 34 }
            PathAttribute { name: "itemOpacity"; value: 0.35 }
            PathAttribute { name: "itemZ"; value: 10 }
            PathPercent { value: 0.125 }

            PathLine { x: main.width * 0.175; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.62 }
            PathAttribute { name: "itemAngle"; value: 28 }
            PathAttribute { name: "itemOpacity"; value: 0.65 }
            PathAttribute { name: "itemZ"; value: 25 }
            PathPercent { value: 0.25 }

            PathLine { x: main.width * 0.3375; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.85 }
            PathAttribute { name: "itemAngle"; value: 18 }
            PathAttribute { name: "itemOpacity"; value: 0.9 }
            PathAttribute { name: "itemZ"; value: 50 }
            PathPercent { value: 0.375 }

            PathLine { x: main.width * 0.5; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 1.15 }
            PathAttribute { name: "itemAngle"; value: 0 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 100 }
            PathPercent { value: 0.5 }

            PathLine { x: main.width * 0.6625; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.85 }
            PathAttribute { name: "itemAngle"; value: -18 }
            PathAttribute { name: "itemOpacity"; value: 0.9 }
            PathAttribute { name: "itemZ"; value: 50 }
            PathPercent { value: 0.625 }

            PathLine { x: main.width * 0.825; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.62 }
            PathAttribute { name: "itemAngle"; value: -28 }
            PathAttribute { name: "itemOpacity"; value: 0.65 }
            PathAttribute { name: "itemZ"; value: 25 }
            PathPercent { value: 0.75 }

            PathLine { x: main.width * 0.9875; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.45 }
            PathAttribute { name: "itemAngle"; value: -34 }
            PathAttribute { name: "itemOpacity"; value: 0.35 }
            PathAttribute { name: "itemZ"; value: 10 }
            PathPercent { value: 0.875 }

            PathLine { x: main.width * 1.15; y: main.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.35 }
            PathAttribute { name: "itemAngle"; value: -38 }
            PathAttribute { name: "itemOpacity"; value: 0.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathPercent { value: 1.0 }
        }

        delegate: Item {
            id: delegateItem
            width: 190
            height: 340

            scale: PathView.itemScale
            opacity: PathView.itemOpacity
            z: PathView.itemZ

            transform: Rotation {
                origin.x: delegateItem.width / 2
                origin.y: delegateItem.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: PathView.itemAngle
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
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
