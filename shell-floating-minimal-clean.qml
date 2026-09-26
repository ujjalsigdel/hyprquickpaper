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
    color: "transparent"

    property string currentImagePath: ""
    property bool bgToggle: false
    property string searchQuery: ""
    property int selectedIndex: 0

    property bool contentRevealed: false

    readonly property int cardSourceW: 960
    readonly property int cardSourceH: 540

    readonly property var defaultVideoExtensions: ["mp4", "webm", "mov", "avi", "mkv", "gif", "m4v", "flv", "wmv", "mpeg", "3gp"]
    readonly property var videoExtensions: (configs.video_extensions && configs.video_extensions.length > 0)
        ? configs.video_extensions
        : defaultVideoExtensions

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
            property var video_extensions: []
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
        nameFilters: {
            const base = ["png", "jpg", "jpeg"].concat(main.videoExtensions)
            if (main.searchQuery.length > 0) {
                return base.map(function(ext) { return "*" + main.searchQuery + "*." + ext })
            }
            return base.map(function(ext) { return "*." + ext })
        }
        sortField: FolderListModel.Name
        onCountChanged: {
            if (count > 0 && selectedIndex >= count) selectedIndex = 0
            initTimer.restart()
        }
    }

    function isVideoFile(fileName) {
        if (!fileName) return false;
        const lower = fileName.toLowerCase();
        for (let i = 0; i < videoExtensions.length; i++) {
            if (lower.endsWith("." + videoExtensions[i])) return true;
        }
        return false;
    }

    function normalizedPath(rawPath) {
        let p = rawPath.replace("~", Quickshell.env("HOME"))
        if (!p.endsWith("/")) p += "/"
        return p
    }

    function getThumbnailSource(fileName) {
        if (!fileName) return "";
        let thumbnailFileName = fileName;
        if (isVideoFile(fileName)) {
            const lastDot = fileName.lastIndexOf(".");
            if (lastDot > 0) {
                thumbnailFileName = fileName.substring(0, lastDot) + ".jpg";
            }
        }
        return "file://" + normalizedPath(configs.cache_path) + thumbnailFileName;
    }

    function getVideoPreviewSource(fileName) {
        if (!fileName) return "";
        const lastDot = fileName.lastIndexOf(".");
        let baseName = fileName;
        if (lastDot > 0) baseName = fileName.substring(0, lastDot);
        return "file://" + normalizedPath(configs.cache_path) + baseName + ".hq.jpg";
    }

    function getFullQualitySource(fileName) {
        if (!fileName) return "";
        if (isVideoFile(fileName)) return getVideoPreviewSource(fileName);
        return "file://" + normalizedPath(configs.wallpaper_path) + fileName;
    }

    function maybeReveal() {
        if (contentRevealed) return
        contentRevealed = true
        revealFallback.stop()
        stage.forceActiveFocus()
    }

    Timer {
        id: revealFallback
        interval: 800
        repeat: false
        running: true
        onTriggered: main.maybeReveal()
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

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(main.selectedIndex, "fileName")
        const fullPath = getFullQualitySource(fileName)
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

    Item {
        id: contentRoot
        anchors.fill: parent
        opacity: main.contentRevealed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            color: "#05070a"
            z: -1
        }

        // 1. CLEAR HIGH-QUALITY BACKGROUND SYSTEM
        Item {
            anchors.fill: parent
            z: 0

            Image {
                id: bgImageA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Screen.width
                sourceSize.height: Screen.height
                opacity: bgToggle ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            Image {
                id: bgImageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Screen.width
                sourceSize.height: Screen.height
                opacity: bgToggle ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#22000000" }
                    GradientStop { position: 1.0; color: "#55000000" }
                }
            }
        }

        // 2. TIERED 3D FLOATING CLOUD — NO REFLECTIONS
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
                    property bool isVideo: main.isVideoFile(safeFileName)
                    property bool imgReady: false

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

                        Rectangle {
                            id: cardMask
                            anchors.fill: parent
                            radius: cardFrame.radius
                            visible: false
                        }

                        Item {
                            id: cardContent
                            anchors.fill: parent
                            visible: false

                            Loader {
                                id: imgLoader
                                anchors.fill: parent
                                active: absDiff <= 10
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

                                        source: main.getThumbnailSource(cardDelegate.safeFileName)

                                        sourceSize.width: main.cardSourceW
                                        sourceSize.height: main.cardSourceH

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
                                            if (status === Image.Ready) {
                                                cardDelegate.imgReady = true
                                            } else if (status === Image.Error) {
                                                cardDelegate.imgReady = false
                                                retryTimer.start()
                                            } else {
                                                cardDelegate.imgReady = false
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: absDiff >= 3 ? 0.3 : 0.0
                            }
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: cardContent
                            maskSource: cardMask
                        }

                        // VIDEO badge — outside cardContent so its visible
                        // binding fires as soon as the image loads, instead
                        // of waiting for the OpacityMask's ShaderEffectSource
                        // to re-capture the texture.
                        Rectangle {
                            id: videoBadge
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: Math.round(cardFrame.radius * 0.5)
                            width: 46
                            height: 18
                            radius: 4
                            color: "#cc000000"
                            border.width: 1
                            border.color: "#44ffffff"
                            z: 20
                            visible: cardDelegate.isVideo && cardDelegate.imgReady

                            Text {
                                anchors.centerIn: parent
                                text: "VIDEO"
                                color: "#ff6666"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 1
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
    }

    function activateCurrent() {
        if (folderModel.count === 0) return
        const filePath = folderModel.get(main.selectedIndex, "filePath")
        Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), filePath])
        Qt.quit()
    }
}
