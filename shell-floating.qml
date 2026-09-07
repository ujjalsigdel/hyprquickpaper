import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "#05070a"

    property string currentImagePath: ""
    property bool bgToggle: false
    property string searchQuery: ""
    property date currentDateTime: new Date()
    property int selectedIndex: 0

    // FontLoader for the futuristic day text
    FontLoader {
        id: customDisplayFont
        source: Quickshell.shellPath("./assets/fonts/anurati-regular.otf")
    }

    anchors { top: true; bottom: true; left: true; right: true }
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])
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
            ? ["*" + searchQuery + "*.png", "*" + searchQuery + "*.jpg", "*" + searchQuery + "*.jpeg"]
            : ["*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
        onCountChanged: {
            if (count > 0 && selectedIndex >= count) selectedIndex = 0
            initTimer.restart()
        }
    }

    property bool didInitialSync: false
    Timer {
        id: initTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (folderModel.count === 0) return

            if (!didInitialSync) {
                didInitialSync = true

                let rawText = ""
                try {
                    rawText = activeWallpaperFile.text
                    if (typeof rawText === "function") {
                        rawText = activeWallpaperFile.text()
                    }
                } catch (e) {
                    rawText = ""
                }
                let activePath = (rawText ? rawText : "").trim()

                if (activePath.length > 0) {
                    for (let i = 0; i < folderModel.count; i++) {
                        if (folderModel.get(i, "filePath") === activePath) {
                            main.selectedIndex = i
                            break
                        }
                    }
                }
            }
            updateBackground()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentDateTime = new Date()
    }

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(main.selectedIndex, "fileName")
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

    onSelectedIndexChanged: updateBackground()

    // -----------------------------------------------------
    // 1. BLURRED BACKGROUND SYSTEM
    // -----------------------------------------------------
    Item {
        anchors.fill: parent
        z: 0

        Image {
            id: bgImageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            opacity: bgToggle ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
        }

        Image {
            id: bgImageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            opacity: bgToggle ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
        }

        MultiEffect {
            anchors.fill: parent
            source: bgImageA
            opacity: bgImageA.opacity
            blurEnabled: true
            blur: 1.0
            blurMax: 80
            brightness: -0.4
            saturation: 0.2
        }

        MultiEffect {
            anchors.fill: parent
            source: bgImageB
            opacity: bgImageB.opacity
            blurEnabled: true
            blur: 1.0
            blurMax: 80
            brightness: -0.4
            saturation: 0.2
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#44000000" }
                GradientStop { position: 0.5; color: "#11000000" }
                GradientStop { position: 1.0; color: "#ee000000" }
            }
        }
    }

    // -----------------------------------------------------
    // 2. TIERED 3D FLOATING CLOUD (REPEATER)
    // -----------------------------------------------------
    Item {
        id: stage
        anchors.fill: parent
        focus: true
        z: 10

        Repeater {
            model: folderModel

            delegate: Item {
                id: cardDelegate

                property string safeFileName: typeof fileName !== "undefined" ? fileName : folderModel.get(index, "fileName")

                property int diff: {
                    let d = index - main.selectedIndex
                    let half = folderModel.count / 2
                    if (d > half) d -= folderModel.count
                    if (d < -half) d += folderModel.count
                    return d
                }

                property real absDiff: Math.abs(diff)

                visible: absDiff <= 8

                property real targetWidth: {
                    if (absDiff === 0) return 640
                    if (absDiff === 1) return 420
                    if (absDiff === 2) return 280
                    return 180
                }

                property real targetHeight: {
                    if (absDiff === 0) return 360
                    if (absDiff === 1) return 236
                    if (absDiff === 2) return 157
                    return 101
                }

                property real targetX: {
                    if (diff === 0) return (main.width - targetWidth) / 2
                    if (absDiff === 1) return (main.width / 2) + (diff * 460) - (targetWidth / 2)
                    if (absDiff === 2) return (main.width / 2) + (Math.sign(diff) * 740) - (targetWidth / 2)
                    return (main.width / 2) + (diff * 200) - (targetWidth / 2)
                }

                property real targetY: {
                    if (absDiff === 0) return main.height * 0.45
                    if (absDiff === 1) return main.height * 0.35
                    if (absDiff === 2) return main.height * 0.28
                    return main.height * 0.05
                }

                property int targetZ: 100 - absDiff
                property real targetOpacity: {
                    if (absDiff === 0) return 1.0
                    if (absDiff === 1) return 0.75
                    if (absDiff === 2) return 0.40
                    return 0.25
                }

                x: targetX
                y: targetY
                width: targetWidth
                height: targetHeight
                z: targetZ
                opacity: targetOpacity

                Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on z { NumberAnimation { duration: 400 } }

                // The actual wallpaper card
                Rectangle {
                    id: cardFrame
                    anchors.fill: parent
                    radius: {
                        if (absDiff === 0) return 28
                        if (absDiff === 1) return 22
                        if (absDiff === 2) return 18
                        return 16
                    }
                    color: "#0a0c10"

                    // Mask shape defining curved corners
                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: cardFrame.radius
                        visible: false
                    }

                    // Content wrapper to clip
                    Item {
                        id: cardContent
                        anchors.fill: parent
                        visible: false

                        Loader {
                            id: imgLoader
                            anchors.fill: parent
                            active: absDiff <= 4
                            asynchronous: true
                            sourceComponent: Item {
                                anchors.fill: parent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Loading..."
                                    color: "#888"
                                    font.pixelSize: 12
                                    visible: cardImg.status !== Image.Ready
                                }

                                Image {
                                    id: cardImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true

                                    source: {
                                        if (!cardDelegate.safeFileName) return "";
                                        let basePath = configs.cache_path.replace("~", Quickshell.env("HOME"));
                                        if (!basePath.endsWith("/")) basePath += "/";
                                        return "file://" + basePath + cardDelegate.safeFileName;
                                    }

                                    sourceSize.width: cardDelegate.targetWidth * 1.5
                                    sourceSize.height: cardDelegate.targetHeight * 1.5

                                    Timer {
                                        id: retryTimer
                                        interval: 1000
                                        repeat: false
                                        onTriggered: {
                                            let s = cardImg.source
                                            cardImg.source = ""
                                            cardImg.source = s
                                        }
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Error) retryTimer.start()
                                    }
                                }
                            }
                        }

                        // Glassy overlay for top row
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: absDiff >= 3 ? 0.3 : 0.0
                        }
                    }

                    // Clipped result masking sharp image corners
                    OpacityMask {
                        anchors.fill: parent
                        source: cardContent
                        maskSource: cardMask
                    }
                }

                // Vertical Reflection Engine
                Item {
                    id: reflectionContainer
                    anchors.top: cardFrame.bottom
                    anchors.left: cardFrame.left
                    anchors.right: cardFrame.right
                    height: cardFrame.height * 0.6
                    clip: true
                    visible: absDiff <= 2
                    opacity: absDiff === 0 ? 0.4 : 0.15

                    Image {
                        width: parent.width
                        height: cardFrame.height
                        anchors.top: parent.top
                        source: (imgLoader.item && imgLoader.item.children[1]) ? imgLoader.item.children[1].source : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        transform: Scale { origin.x: width/2; origin.y: height/2; yScale: -1 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#22000000" }
                            GradientStop { position: 0.7; color: "#ff000000" }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        stage.forceActiveFocus()
                        if (main.selectedIndex === index) {
                            main.activateCurrent()
                        } else {
                            main.selectedIndex = index
                        }
                    }
                }
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                main.selectedIndex = (main.selectedIndex + 1) % folderModel.count
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                main.selectedIndex = (main.selectedIndex - 1 + folderModel.count) % folderModel.count
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                main.activateCurrent()
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit()
            } else {
                return
            }
            event.accepted = true
        }
    }

    // -----------------------------------------------------
    // 3. DATE & TIME OVERLAY (Glassmorphic Top-Center)
    // -----------------------------------------------------
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: main.height * 0.08
        width: 320
        height: 140
        z: 100

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: "#1affffff"
            border.width: 1
            border.color: "#33ffffff"

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 32
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(currentDateTime, "dddd").toUpperCase()
                color: "#f2f2f2"
                font.pixelSize: 52
                font.letterSpacing: 12
                font.family: customDisplayFont.name
                style: Text.Raised
                styleColor: "#88000000"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(currentDateTime, "dd MMM yyyy").toUpperCase()
                color: "#cccccc"
                font.pixelSize: 14
                font.letterSpacing: 4
                font.family: "sans-serif"
                font.weight: Font.Bold
            }

            Item { width: 1; height: 10 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(currentDateTime, "h:mm AP")
                color: "#999999"
                font.pixelSize: 12
                font.letterSpacing: 2
                font.family: "sans-serif"
            }
        }
    }

    function activateCurrent() {
        if (folderModel.count === 0) return
        const filePath = folderModel.get(main.selectedIndex, "filePath")
        Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), filePath])
        Qt.quit()
    }
}
