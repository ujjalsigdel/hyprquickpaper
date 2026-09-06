import Quickshell
import Quickshell.Io // for Process
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

    // Explicitly enable alpha transparency for the Wayland surface
    WlrLayershell.namespace: "hyprquickpaper"

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir]);
        console.log(Quickshell.shellDir);
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

    // Read active wallpaper path from the ML4W user cache
    FileView {
        id: activeWallpaperFile
        path: Quickshell.env("HOME") + "/.cache/hyprquickpaper/current_wallpaper"
        watchChanges: false
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path.replace("~", Quickshell.env("HOME"))
        showDirs: false
        nameFilters: ["*.png", "*.jpg"]
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
        // reuseItems: true
        cacheBuffer: width * 2

        property int selectedIndex: 0
        property real tileWidth: width / configs.number_of_pictures - 10

        // Helper function to focus and center the selected index properly
        function centerOnIndex(idx) {
            selectedIndex = idx
            positionViewAtIndex(idx, ListView.Center)
            ensureVisibleAnimated(idx)
        }

        // NEW CODE (Wraps around endlessly in both directions):
        function clampIndex(i) {
            if (count === 0)
                return 0;
            return (i % count + count) % count;
        }

        // Delay centering slightly so Qt Quick layout metrics complete rendering
        Timer {
            id: initTimer
            interval: 50
            repeat: false
            onTriggered: {
                if (folderModel.count === 0) return

                // Retrieve current wallpaper path via text() function call
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

                // Fallback to exact middle item if current wallpaper is not matched
                if (matchedIndex === -1) {
                    matchedIndex = Math.floor(folderModel.count / 2)
                }

                list.centerOnIndex(matchedIndex)
            }
        }

        Connections {
            target: folderModel
            function onCountChanged() {
                initTimer.restart()
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
                // velocity: v
                duration: 100
            }
        }
        Component.onCompleted: {
            anim.v = main.speed;
        }

        delegate: Item {
            property bool active: index === list.selectedIndex
            width: list.tileWidth
            // width: active? 1000:list.tileWidth
            height: 500
            // visible: shownNow
            Behavior on width {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.OutCubic
                }
            }
            // anchors.centerIn: parent

            // property bool shownNow:
            //     index >= list.selectedIndex - configs.number_of_pictures &&
            //     index <= list.selectedIndex + configs.number_of_pictures

            Text {
                id: alt
                text: "Loading..."
                color: configs.border_color
                anchors.centerIn: parent
                font.pixelSize: 16
                transform: Shear {
                    xFactor: -0.25
                }
            }
            Image {
                id: img
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: false
                smooth: true

                source: "file://" + configs.cache_path.replace("~", Quickshell.env("HOME")) + fileName

                // kind of an on-demand loading
                // source: shownNow
                //     ? "file://" + configs.cache_path + fileName
                //     : ""

                sourceSize.width: width
                sourceSize.height: height

                transform: Shear {
                    xFactor: -0.25
                }

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
            Rectangle {
                id: border
                z: 10
                visible: parent.active
                width: list.tileWidth
                height: 500
                color: "transparent"

                border.width: 4
                border.color: configs.border_color

                transform: Shear {
                    xFactor: -0.25
                }

                // x: list.selectedIndex * (width + list.spacing) - list.contentX

                // Behavior on x {
                //     NumberAnimation {
                //         duration: 160
                //         easing.type: Easing.OutCubic
                //     }
                // }
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

            if (event.key === Qt.Key_L) {
                anim.v = main.speed;
                selectedIndex = clampIndex(selectedIndex + step);
                ensureVisibleAnimated(selectedIndex);
            } else if (event.key === Qt.Key_H) {
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
