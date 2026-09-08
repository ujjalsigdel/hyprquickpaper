import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    property int speed: 5000

    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "hyprquickpaper"

    // Mirrors get_video_extensions_pattern() in common.sh: prefer
    // config.json's "video_extensions", fall back to this default list
    // if it's missing/empty. Kept as a live binding (not a one-time
    // value) so editing config.json and letting it reload updates the
    // picker's file list too, not just the bash backend.
    readonly property var defaultVideoExtensions: ["mp4", "webm", "mov", "avi", "mkv", "gif", "m4v", "flv", "wmv", "mpeg", "3gp"]
    readonly property var videoExtensions: (configs.video_extensions && configs.video_extensions.length > 0)
        ? configs.video_extensions
        : defaultVideoExtensions

    function isVideoFile(fileName) {
        if (!fileName) return false;
        const lower = fileName.toLowerCase();
        for (let i = 0; i < videoExtensions.length; i++) {
            if (lower.endsWith("." + videoExtensions[i])) return true;
        }
        return false;
    }

    function getThumbnailSource(fileName) {
        if (!fileName) return "";
        let basePath = configs.cache_path.replace("~", Quickshell.env("HOME"));
        if (!basePath.endsWith("/")) basePath += "/";
        
        let thumbnailFileName = fileName;
        if (isVideoFile(fileName)) {
            const lastDot = fileName.lastIndexOf(".");
            if (lastDot > 0) {
                thumbnailFileName = fileName.substring(0, lastDot) + ".jpg";
            }
        }
        return "file://" + basePath + thumbnailFileName;
    }

    // DEFER thumbnail generation script run to avoid UI lag on open
    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir]);
        }
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
        nameFilters: ["*.png", "*.jpg", "*.jpeg"].concat(
            main.videoExtensions.map(function(ext) { return "*." + ext; })
        )
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true

        model: folderModel
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        // Prefetch adjacent tiles into memory for smooth panning
        cacheBuffer: width * 1.5

        property int selectedIndex: 0
        // Math.max(1, ...) guards against a 0 or unset number_of_pictures
        // in config.json dividing by zero and blowing up tileWidth.
        property real tileWidth: width / Math.max(1, configs.number_of_pictures) - 10

        function centerOnIndex(idx) {
            selectedIndex = idx;
            positionViewAtIndex(idx, ListView.Center);
            ensureVisibleAnimated(idx);
        }

        function clampIndex(i) {
            if (count === 0) return 0;
            return (i % count + count) % count;
        }

        Timer {
            id: initTimer
            interval: 16 // 1 frame delay
            repeat: false
            onTriggered: {
                if (folderModel.count === 0) return;

                let rawText = activeWallpaperFile.text() ? activeWallpaperFile.text() : "";
                let activePath = rawText.trim();
                let matchedIndex = -1;

                if (activePath.length > 0) {
                    for (let i = 0; i < folderModel.count; i++) {
                        if (folderModel.get(i, "filePath") === activePath) {
                            matchedIndex = i;
                            break;
                        }
                    }
                }

                if (matchedIndex === -1) {
                    matchedIndex = Math.floor(folderModel.count / 2);
                }

                list.centerOnIndex(matchedIndex);
            }
        }

        Connections {
            target: folderModel
            function onCountChanged() {
                initTimer.restart();
            }
        }

        function activateCurrent() {
            const path = folderModel.get(selectedIndex, "filePath");
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            Qt.quit();
        }

        function clampX(x) {
            return Math.max(0, Math.min(x, contentWidth - width));
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing;
            const itemStart = i * step;
            const itemEnd = itemStart + tileWidth + 20;

            if (itemStart < contentX)
                contentX = clampX(itemStart);
            else if (itemEnd > contentX + width)
                contentX = clampX(itemStart - (width - step));
        }

        Behavior on contentX {
            SmoothedAnimation {
                id: anim
                property int v: 10
                duration: 100
            }
        }

        Component.onCompleted: {
            anim.v = main.speed;
        }

        delegate: Item {
            property bool active: index === list.selectedIndex
            property bool isVideo: main.isVideoFile(fileName)
            property int retryCount: 0
            property int maxRetries: isVideo ? 20 : 6
            width: list.tileWidth
            height: 500

            Behavior on width {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: alt
                text: "Loading..."
                color: configs.border_color
                anchors.centerIn: parent
                font.pixelSize: 16
                transform: Shear { xFactor: -0.25 }
                visible: img.status !== Image.Ready
            }
            
            Image {
                id: img
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // ENABLED CACHING for instant subsequent opens
                cache: true
                smooth: false // Use false for higher rendering throughput during fast scroll
                source: main.getThumbnailSource(fileName)
                sourceSize.width: width
                sourceSize.height: height

                transform: Shear { xFactor: -0.25 }

                Timer {
                    id: retryTimer
                    interval: 200
                    repeat: false
                    onTriggered: {
                        if (img.status !== Image.Ready) {
                            let s = img.source;
                            img.source = "";
                            // Defer reassignment to the next event-loop tick
                            // rather than doing it synchronously inline.
                            Qt.callLater(function() {
                                img.source = s;
                            });
                            retryCount++;
                            if (retryCount < maxRetries) {
                                // Back off instead of hammering every 200ms —
                                // ffmpeg-generated video thumbnails can take
                                // a while to land on first run.
                                retryTimer.interval = Math.min(retryTimer.interval * 1.5, 2000);
                                retryTimer.start();
                            } else {
                                alt.text = isVideo ? "🎬" : "✖";
                            }
                        }
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        alt.text = "";
                        retryCount = 0;
                    } else if (status === Image.Error) {
                        if (retryCount < maxRetries) {
                            retryTimer.start();
                        } else {
                            alt.text = isVideo ? "🎬" : "✖";
                        }
                    }
                }
            }
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
                width: 50
                height: 20
                radius: 4
                color: "#cc000000"
                border.width: 1
                border.color: "#44ffffff"
                z: 20
                visible: isVideo && img.status === Image.Ready
                
                Text {
                    anchors.centerIn: parent
                    text: "VIDEO"
                    color: "#ff6666"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
            }

            Rectangle {
                id: border
                z: 10
                visible: parent.active
                width: list.tileWidth
                height: 500
                color: "transparent"
                border.width: 4
                border.color: configs.border_color
                transform: Shear { xFactor: -0.25 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.selectedIndex = index;
                    list.activateCurrent();
                }
                onWheel: function (wheel) {
                    list.contentX = list.clampX(list.contentX - wheel.angleDelta.y * 2);
                    wheel.accepted = false;
                }
            }
        }

        Keys.onPressed: function (event) {
            const step = 1;
            const big = configs.number_of_pictures;

            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                anim.v = main.speed;
                selectedIndex = clampIndex(selectedIndex + step);
                ensureVisibleAnimated(selectedIndex);
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                anim.v = main.speed;
                selectedIndex = clampIndex(selectedIndex - step);
                ensureVisibleAnimated(selectedIndex);
            } else if (event.key === Qt.Key_U) {
                anim.v = main.speed * big;
                selectedIndex = clampIndex(selectedIndex + big);
                ensureVisibleAnimated(selectedIndex);
            } else if (event.key === Qt.Key_D) {
                anim.v = main.speed * big;
                selectedIndex = clampIndex(selectedIndex - big);
                ensureVisibleAnimated(selectedIndex);
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                activateCurrent();
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else
                return;
            event.accepted = true;
        }
    }
}
