import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
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
        path: Quickshell.env("HOME") + "/.cache/hyprquickpaper/current_wallpaper"
        watchChanges: false
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path.replace("~", Quickshell.env("HOME"))
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
    }

    // Normalizes a config path: expands ~ and guarantees a trailing
    // slash, so direct string concatenation with a fileName never
    // produces a broken "...folderimage.png" path.
    function normalizedPath(rawPath) {
        let p = rawPath.replace("~", Quickshell.env("HOME"))
        if (!p.endsWith("/")) p += "/"
        return p
    }

    function updateBackground() {
        if (folderModel.count === 0) return
        const fileName = folderModel.get(pathView.currentIndex, "fileName")
        // Full-quality source for the background — wallpaper_path (the
        // original folder), NOT cache_path. cache_path holds downscaled
        // thumbnails generated for the small deck cards; reusing them
        // here was why the background looked degraded.
        const fullPath = "file://" + normalizedPath(configs.wallpaper_path) + fileName
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
    // LOSSLESS FULL-QUALITY BACKGROUND
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
            opacity: bgToggle ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }

            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("BG LOAD FAILED (bgImageA):", source)
                }
            }
        }

        Image {
            id: bgImageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            opacity: bgToggle ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }

            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("BG LOAD FAILED (bgImageB):", source)
                }
            }
        }
    }

    // -----------------------------------------------------
    // UNIFORM-HEIGHT BOTTOM DOCK WITH CURVED CORNERS
    // -----------------------------------------------------
    PathView {
        id: pathView
        anchors.fill: parent
        focus: true
        interactive: false

        model: folderModel
        pathItemCount: 15
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
            startX: -main.width * 0.12
            startY: main.height - 180

            PathAttribute { name: "itemScale"; value: 1.0 }
            PathAttribute { name: "itemOpacity"; value: 0.95 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathPercent { value: 0.0 }

            PathLine { x: main.width * 0.5; y: main.height - 180 }
            PathAttribute { name: "itemScale"; value: 1.30 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 100 }
            PathPercent { value: 0.5 }

            PathLine { x: main.width * 1.12; y: main.height - 180 }
            PathAttribute { name: "itemScale"; value: 1.0 }
            PathAttribute { name: "itemOpacity"; value: 0.95 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathPercent { value: 1.0 }
        }

        delegate: Item {
            id: delegateItem
            width: 340
            height: 215

            // Capture the attached property here, at the delegate ROOT,
            // where PathView guarantees it resolves correctly. Nested
            // children below read delegateItem.isCurrent instead of
            // trying to resolve "PathView.isCurrentItem" themselves —
            // reading it directly from a nested grandchild was silently
            // evaluating false for every card, which is why the border
            // never distinguished the selected card regardless of color.
            property bool isCurrent: PathView.isCurrentItem

            scale: PathView.itemScale
            opacity: PathView.itemOpacity
            z: isCurrent ? 100 : PathView.itemZ

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, -0.22, 0, 0.22 * 215 / 2,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
            }

            // Card item wrapper
            Item {
                anchors.fill: parent

                // Inner Mask shape defining curved corners
                Rectangle {
                    id: mask
                    anchors.fill: parent
                    radius: 14
                    visible: false
                }

                // Background & Wallpaper Image
                Rectangle {
                    id: cardContent
                    anchors.fill: parent
                    color: "#1e1e2e"
                    visible: false

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

                // Clipped rounded card result
                OpacityMask {
                    anchors.fill: parent
                    source: cardContent
                    maskSource: mask
                }

                // Selected border: a single rectangle whose border
                // color/width switch based on isCurrentItem. Kept to one
                // lean Rectangle (no extra negative-margin glow layers)
                // so it can't introduce any new failure surface.
                Rectangle {
                    id: selectedBorder
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    antialiasing: true
                    border.width: delegateItem.isCurrent ? 2 : 1
                    border.color: delegateItem.isCurrent
                        ? (configs.border_color.length > 0 ? configs.border_color : "#e6e6e6")
                        : "#33ffffff"
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
