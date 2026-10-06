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

    // -----------------------------------------------------
    // COVERFLOW TUNABLES
    // -----------------------------------------------------
    property real cardW: 190
    property real cardH: 340
    property real centerScale: 1.15
    property real edgeScale: 0.55
    property real gapPx: 20

    property real skewFactor: -0.18

    readonly property var defaultVideoExtensions: ["mp4", "webm", "mov", "avi", "mkv", "gif", "m4v", "flv", "wmv", "mpeg", "3gp"]
    readonly property var videoExtensions: (configs.video_extensions && configs.video_extensions.length > 0)
        ? configs.video_extensions
        : defaultVideoExtensions

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
        nameFilters: ["png", "jpg", "jpeg"].concat(main.videoExtensions)
            .map(function(ext) { return "*." + ext })
        sortField: FolderListModel.Name
    }

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(pathView.currentIndex, "fileName")

        let fullPath
        if (isVideoFile(fileName)) {
            fullPath = getVideoPreviewSource(fileName)
        } else {
            fullPath = "file://" + normalizedPath(configs.wallpaper_path) + fileName
        }

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
    // CRISP, FULL-QUALITY BACKGROUND
    // -----------------------------------------------------
    Item {
        id: backgroundLayer
        anchors.fill: parent
        opacity: pathView.opacity

        Image {
            id: bgImageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
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

    // -----------------------------------------------------
    // FLAT ROW OF UNIFORMLY-SHEARED (PARALLELOGRAM) CARDS
    // -----------------------------------------------------
    PathView {
        id: pathView
        anchors.fill: parent
        focus: true
        interactive: false

        // Hidden until the current card's image is ready, then faded in.
        // Prevents the brief "empty box + Loading..." frame on open.
        opacity: 0
        property bool hasRevealed: false
        property bool currentImageReady: false

        model: folderModel
        pathItemCount: 11
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5

        onCurrentIndexChanged: {
            updateBackground()
            // Only re-arm the ready flag during initial setup; after the
            // first reveal, don't reset it (we don't want to re-hide the
            // view every time the user scrolls).
            if (!hasRevealed) {
                currentImageReady = false
            }
        }

        NumberAnimation {
            id: revealAnimation
            target: pathView
            property: "opacity"
            to: 1
            duration: 20
            easing.type: Easing.OutCubic
        }

        function tryReveal() {
            if (hasRevealed) return
            if (!currentImageReady) return
            hasRevealed = true
            revealFallback.stop()
            revealAnimation.start()
        }

        Connections {
            target: pathView
            function onCurrentImageReadyChanged() {
                pathView.tryReveal()
            }
        }

        // Fallback: if the current image never reports ready (missing
        // file, decoder hiccup), still show something after a moment so
        // the panel isn't stuck fully transparent.
        Timer {
            id: revealFallback
            interval: 600
            repeat: false
            onTriggered: {
                if (!pathView.hasRevealed) {
                    pathView.hasRevealed = true
                    revealAnimation.start()
                }
            }
        }

        Timer {
            id: initTimer
            interval: 16
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

                // Give the new current delegate a chance to load; if it
                // doesn't report ready in time, the fallback fires.
                revealFallback.restart()
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

            property bool isCurrent: PathView.isCurrentItem
            property bool isVideo: main.isVideoFile(model.fileName)

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
                border.width: delegateItem.isCurrent ? 3 : 1
                border.color: delegateItem.isCurrent ? configs.border_color : "#22ffffff"

                Text {
                    id: alt
                    text: "Loading..."
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 14
                    visible: img.status !== Image.Ready
                }

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true

                    source: main.getThumbnailSource(fileName)

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
                        if (status === Image.Ready) {
                            alt.text = "";
                            // Signal to the parent PathView that the
                            // currently-selected card is ready, so the
                            // reveal animation can fire.
                            if (delegateItem.isCurrent) {
                                pathView.currentImageReady = true
                            }
                        } else if (status === Image.Error) {
                            alt.text = "Caching";
                            retryTimer.start();
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 10
                    width: 46
                    height: 18
                    radius: 4
                    color: "#cc000000"
                    border.width: 1
                    border.color: "#44ffffff"
                    z: 20
                    visible: delegateItem.isVideo && img.status === Image.Ready

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
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
