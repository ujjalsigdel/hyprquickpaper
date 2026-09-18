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

    PathView {
        id: list
        anchors.fill: parent
        focus: true

        model: folderModel

        property real tileWidth: width / Math.max(1, configs.number_of_pictures) - 10
        property real spacing: 4
        property real step: tileWidth + spacing

        property int peekCount: 2
        pathItemCount: Math.max(1, Math.min(folderModel.count, configs.number_of_pictures + peekCount * 2))

        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange

        highlightMoveDuration: Math.max(50, (step / main.speed) * 1000)

        path: Path {
            startX: list.width / 2 - (list.pathItemCount * list.step) / 2
            startY: main.height / 2
            PathLine {
                x: list.width / 2 + (list.pathItemCount * list.step) / 2
                y: main.height / 2
            }
        }

        function clampIndex(i) {
            if (count === 0) return 0;
            return (i % count + count) % count;
        }

        function centerOnIndex(idx) {
            currentIndex = idx;
        }

        function activateCurrent() {
            const path = folderModel.get(currentIndex, "filePath");
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            Qt.quit();
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

        delegate: Item {
            id: delegateItem
            property bool isCurrent: PathView.isCurrentItem
            property bool isVideo: main.isVideoFile(fileName)
            property bool nearFocus: Math.abs(index - list.currentIndex) <= 3
            property int retryCount: 0
            property int maxRetries: isVideo ? 20 : 6
            width: list.tileWidth
            height: 500

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
                cache: true
                smooth: delegateItem.nearFocus
                source: main.getThumbnailSource(fileName)
                sourceSize.width: width * 1.25
                sourceSize.height: height * 1.25

                transform: Shear { xFactor: -0.25 }

                Timer {
                    id: retryTimer
                    interval: 200
                    repeat: false
                    onTriggered: {
                        if (img.status !== Image.Ready) {
                            let s = img.source;
                            img.source = "";
                            Qt.callLater(function() {
                                img.source = s;
                            });
                            delegateItem.retryCount++;
                            if (delegateItem.retryCount < delegateItem.maxRetries) {
                                retryTimer.interval = Math.min(retryTimer.interval * 1.5, 2000);
                                retryTimer.start();
                            } else {
                                alt.text = delegateItem.isVideo ? "🎬" : "✖";
                            }
                        }
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        alt.text = "";
                        delegateItem.retryCount = 0;
                    } else if (status === Image.Error) {
                        if (delegateItem.retryCount < delegateItem.maxRetries) {
                            retryTimer.start();
                        } else {
                            alt.text = delegateItem.isVideo ? "🎬" : "✖";
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

            Rectangle {
                id: border
                z: 10
                visible: delegateItem.isCurrent
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
                    if (list.currentIndex === index) {
                        list.activateCurrent();
                    } else {
                        list.currentIndex = index;
                    }
                }
            }
        }

        Keys.onPressed: function (event) {
            const big = configs.number_of_pictures;

            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                incrementCurrentIndex();
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                decrementCurrentIndex();
            } else if (event.key === Qt.Key_U) {
                currentIndex = clampIndex(currentIndex + big);
            } else if (event.key === Qt.Key_D) {
                currentIndex = clampIndex(currentIndex - big);
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
