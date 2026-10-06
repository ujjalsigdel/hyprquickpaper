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
    // Transparent surface; the dark backdrop is an inner Rectangle that
    // fades in with the rest of the content, so the user never sees an
    // empty dark panel before the images are ready.
    color: "transparent"

    property string currentImagePath: ""
    property string appliedWallpaperPath: ""
    property bool bgToggle: false
    property string searchQuery: ""
    property int selectedIndex: 0

    // Reveal state: false until the first background image is decoded.
    property bool contentRevealed: false

    // Grid Layout Settings
    property real leftPanelWidth: width * 0.40
    property int gridColumns: 3
    property real gridOuterMargin: 32
    property real cellW: Math.floor((leftPanelWidth - (gridOuterMargin * 2)) / gridColumns)
    property real cellH: cellW * (9/16)

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

    // Any background image becoming Ready reveals the panel.
    // Called from both bgImageA and bgImageB onStatusChanged.
    function maybeReveal() {
        if (!contentRevealed) {
            contentRevealed = true
            revealFallback.stop()
            leftPanel.forceActiveFocus()
        }
    }

    // Safety net: if the background never reports Ready (missing file,
    // decoder issue), still show the picker so it isn't stuck invisible.
    Timer {
        id: revealFallback
        interval: 500
        repeat: false
        running: true
        onTriggered: main.maybeReveal()
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

    // --- INITIAL SYNC LOGIC ---
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
                } catch (e) { rawText = "" }
                let activePath = (rawText ? rawText : "").trim()

                let activeFileName = ""
                if (activePath.length > 0) {
                    const slash = activePath.lastIndexOf("/")
                    if (slash >= 0) activeFileName = activePath.substring(slash + 1)
                }
                if (activeFileName.length > 0 && isVideoFile(activeFileName)) {
                    main.appliedWallpaperPath = getVideoPreviewSource(activeFileName)
                } else {
                    main.appliedWallpaperPath = "file://" + activePath
                }

                if (activePath.length > 0) {
                    for (let i = 0; i < folderModel.count; i++) {
                        if (folderModel.get(i, "filePath") === activePath) {
                            main.selectedIndex = i
                            wallpaperGrid.currentIndex = i
                            wallpaperGrid.positionViewAtIndex(i, GridView.Beginning)
                            break
                        }
                    }
                }
            }
            updateViews()
        }
    }

    function updateViews() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(main.selectedIndex, "fileName")
        const fullPath = getFullQualitySource(fileName)

        currentImagePath = fullPath
        if (!bgToggle) {
            bgImageB.source = fullPath
            previewImageB.source = fullPath
            bgToggle = true
        } else {
            bgImageA.source = fullPath
            previewImageA.source = fullPath
            bgToggle = false
        }
    }

    // -----------------------------------------------------
    // CONTENT ROOT
    // Everything visible lives inside this Item. Its opacity is 0
    // until the first background image is Ready, then it fades in as
    // a single unit. That removes the "black screen then images pop
    // in" sequence and hides any late-loading preview boxes.
    // -----------------------------------------------------
    Item {
        id: contentRoot
        anchors.fill: parent
        opacity: main.contentRevealed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Dark backdrop that replaces the panel's own color, so it
        // fades in together with the images instead of being painted
        // instantly on open.
        Rectangle {
            anchors.fill: parent
            color: "#05070a"
            z: -1
        }

        // -----------------------------------------------------
        // 1. BLURRED BACKGROUND
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
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            Image {
                id: bgImageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                opacity: bgToggle ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                onStatusChanged: if (status === Image.Ready) main.maybeReveal()
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImageA
                opacity: bgImageA.opacity
                blurEnabled: true
                blur: 1.0
                blurMax: 80
                brightness: -0.35
                saturation: 0.15
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImageB
                opacity: bgImageB.opacity
                blurEnabled: true
                blur: 1.0
                blurMax: 80
                brightness: -0.35
                saturation: 0.15
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#22000000" }
                    GradientStop { position: 1.0; color: "#cc000000" }
                }
            }
        }

        // -----------------------------------------------------
        // 2. LEFT PANEL (Grid & Key Handlers)
        // -----------------------------------------------------
        Rectangle {
            id: leftPanel
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: main.leftPanelWidth
            color: "#8805070a" 
            z: 10
            focus: true
            
            Rectangle {
                anchors.left: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 40
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#99000000" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }
            
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: "#1affffff"
            }

            GridView {
                id: wallpaperGrid
                anchors.fill: parent
                anchors.margins: main.gridOuterMargin
                
                cellWidth: main.cellW
                cellHeight: main.cellH
                
                model: folderModel
                currentIndex: main.selectedIndex
                clip: true
                interactive: true

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight
                    property bool isSelected: index === main.selectedIndex
                    property string safeFileName: typeof fileName !== "undefined" ? fileName : folderModel.get(index, "fileName")
                    property bool isVideo: main.isVideoFile(safeFileName)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 8
                        color: "#0a0c10"
                        
                        border.width: isSelected ? 3 : 1
                        border.color: isSelected ? (configs.border_color || "#70a0ff") : "#22ffffff"
                        clip: true
                        
                        Image {
                            id: gridImg
                            anchors.fill: parent
                            anchors.margins: isSelected ? 3 : 0
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            source: main.getThumbnailSource(safeFileName)
                            sourceSize.width: wallpaperGrid.cellWidth * 1.5
                            sourceSize.height: wallpaperGrid.cellHeight * 1.5
                        }

                        Text {
                            anchors.centerIn: parent
                            text: gridImg.status === Image.Error ? (isVideo ? "🎬" : "✖") : ""
                            color: "#8899a3"
                            font.pixelSize: 20
                            visible: gridImg.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: isSelected ? 0.0 : 0.45
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            width: 42
                            height: 16
                            radius: 3
                            color: "#cc000000"
                            border.width: 1
                            border.color: "#44ffffff"
                            z: 20
                            visible: isVideo && gridImg.status === Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: "VIDEO"
                                color: "#ff6666"
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            main.selectedIndex = index
                            leftPanel.forceActiveFocus()
                            updateViews()
                        }
                        onDoubleClicked: {
                            main.selectedIndex = index
                            main.activateCurrent()
                        }
                    }
                }
            }

            Keys.onPressed: function(event) {
                let nextIndex = main.selectedIndex;
                
                if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    nextIndex++;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    nextIndex--;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    nextIndex += main.gridColumns;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    nextIndex -= main.gridColumns;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    main.activateCurrent();
                    event.accepted = true; return;
                } else if (event.key === Qt.Key_Escape) {
                    Qt.quit();
                    event.accepted = true; return;
                } else { return; }
                
                if (nextIndex >= 0 && nextIndex < folderModel.count) {
                    main.selectedIndex = nextIndex;
                    wallpaperGrid.currentIndex = nextIndex;
                    wallpaperGrid.positionViewAtIndex(nextIndex, GridView.Contain);
                    updateViews();
                }
                event.accepted = true;
            }
        }

        // -----------------------------------------------------
        // 3. RIGHT PANEL (Current vs New View)
        // -----------------------------------------------------
        Item {
            id: rightPanel
            anchors.left: leftPanel.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 5

            Column {
                anchors.centerIn: parent
                spacing: 32

                Column {
                    spacing: 12
                    
                    Text {
                        text: "CURRENTLY ACTIVE"
                        color: configs.border_color || "#70a0ff"
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        property real w: rightPanel.width * 0.40
                        width: w
                        height: w * (9/16)
                        radius: 12
                        color: "#0a0c10"
                        border.width: 1
                        border.color: "#33ffffff"
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: main.appliedWallpaperPath
                        }
                    }
                }

                Column {
                    spacing: 12

                    Text {
                        text: "NEW SELECTION"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        id: newSelectionBox
                        property real w: rightPanel.width * 0.80
                        width: w
                        height: w * (9/16)
                        radius: 16
                        color: "#0a0c10"
                        border.width: 1
                        border.color: "#44ffffff"
                        clip: true

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#000000"
                            shadowOpacity: 0.6
                            shadowBlur: 1.5
                            shadowVerticalOffset: 12
                        }

                        Image {
                            id: previewImageA
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: bgToggle ? 0.0 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                        }
                        Image {
                            id: previewImageB
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: bgToggle ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                        }
                    }

                    Item {
                        width: newSelectionBox.w
                        height: 22

                        Text {
                            anchors.left: parent.left
                            width: parent.width * 0.6
                            text: folderModel.count > 0 ? folderModel.get(main.selectedIndex, "fileName") : ""
                            color: "#f2f2f2"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }
                        Text {
                            anchors.right: parent.right
                            text: "ENTER to apply · ESC to close"
                            color: "#8899a3"
                            font.pixelSize: 12
                        }
                    }
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
