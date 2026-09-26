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
    property date currentDateTime: new Date()
    property int selectedIndex: 0

    property bool contentRevealed: false

    readonly property int cardSourceW: 960
    readonly property int cardSourceH: 540

    readonly property var defaultVideoExtensions: ["mp4", "webm", "mov", "avi", "mkv", "gif", "m4v", "flv", "wmv", "mpeg", "3gp"]
    readonly property var videoExtensions: (configs.video_extensions && configs.video_extensions.length > 0)
        ? configs.video_extensions
        : defaultVideoExtensions

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

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentDateTime = new Date()
    }

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(main.selectedIndex, "fileName")
        const fullPath = getThumbnailSource(fileName)
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

        // 1. BLURRED BACKGROUND SYSTEM
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
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            Image {
                id: bgImageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                opacity: bgToggle ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImageA
                opacity: bgImageA.opacity
                blurEnabled: true
                blur: 1.0
                blurMax: 80
                brightness: -0.15
                saturation: 0.15
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImageB
                opacity: bgImageB.opacity
                blurEnabled: true
                blur: 1.0
                blurMax: 80
                brightness: -0.15
                saturation: 0.15
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: "#22000000" } 
                    GradientStop { position: 0.35; color: "#00000000" } 
                    GradientStop { position: 0.7;  color: "#00000000" } 
                    GradientStop { position: 0.85; color: "#66000000" } 
                    GradientStop { position: 1.0;  color: "#ee000000" } 
                }
            }
        }

        // 2. TIERED 3D FLOATING CLOUD
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
                    // Surfaced from the Loader's Image so the VIDEO badge —
                    // which now lives outside cardContent — can bind to it.
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
                        // binding is honoured the moment the image loads,
                        // instead of waiting for the OpacityMask's internal
                        // ShaderEffectSource to re-capture the texture.
                        // Positioned inside the rounded safe area so it
                        // doesn't need clipping.
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

                    // Reflection
                    Item {
                        id: reflectionContainer
                        anchors.top: cardFrame.bottom
                        anchors.left: cardFrame.left
                        anchors.right: cardFrame.right
                        height: cardFrame.height * 0.6
                        visible: absDiff <= 2

                        opacity: {
                            if (absDiff === 0) return 0.65
                            if (absDiff === 1) return 0.35
                            return 0.20
                        }

                        Item {
                            id: reflectionContent
                            anchors.fill: parent
                            visible: false

                            Image {
                                id: reflectionImg
                                width: parent.width
                                height: cardFrame.height
                                anchors.top: parent.top

                                source: main.getThumbnailSource(cardDelegate.safeFileName)

                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                transform: Scale {
                                    origin.x: width/2
                                    origin.y: height/2
                                    yScale: -1
                                }

                                sourceSize.width: main.cardSourceW
                                sourceSize.height: main.cardSourceH
                            }
                        }

                        Item {
                            id: reflectionMask
                            anchors.fill: parent
                            visible: false

                            Rectangle {
                                width: parent.width
                                height: parent.height
                                radius: cardFrame.radius
                                color: "black"
                            }
                        }

                        OpacityMask {
                            id: maskedReflection
                            anchors.fill: parent
                            source: reflectionContent
                            maskSource: reflectionMask
                        }

                        Item {
                            anchors.fill: parent

                            Loader {
                                anchors.fill: parent
                                sourceComponent: maskedReflection
                                asynchronous: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#00000000" }
                                    GradientStop { position: 0.5; color: "#00000000" }
                                    GradientStop { position: 0.8; color: "#22000000" }
                                    GradientStop { position: 0.95; color: "#88000000" }
                                    GradientStop { position: 1.0; color: "#dd000000" }
                                }
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

        // 3. DATE & TIME OVERLAY
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
    }

    function activateCurrent() {
        if (folderModel.count === 0) return
        const filePath = folderModel.get(main.selectedIndex, "filePath")
        Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), filePath])
        Qt.quit()
    }
}
