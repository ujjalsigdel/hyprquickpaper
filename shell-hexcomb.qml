import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"

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

    // -----------------------------------------------------
    // HEXAGON GRID TUNABLES
    // -----------------------------------------------------
    // Flat-top regular hexagon: height = width * sqrt(3)/2
    // These "base*" values are the MINIMUM tile size — the grid never
    // goes smaller than this. For however many wallpapers you have,
    // computeLayout() searches over possible column counts and picks
    // whichever one (combined with a scale-up factor) fills the most
    // of the screen without overflowing it or shrinking below the
    // minimum. With few wallpapers this can mean fewer, much bigger
    // columns that fill the whole screen; with many wallpapers no
    // column count fits at any scale ≥ 1, so it falls back to the
    // minimum size and the grid becomes scrollable instead.
    property real baseCardW: 220
    property real baseCardH: baseCardW * 0.866
    property real baseHSpacing: 6
    property real baseVSpacing: 6
    property real baseColStep: baseCardW * 0.75 + baseHSpacing
    property real baseRowStep: baseCardH + baseVSpacing
    property real maxGridScale: 2.5

    // -----------------------------------------------------
    // Exact footprint of a hex-honeycomb grid of `count` tiles laid
    // out over `cols` columns, given the tile metrics passed in.
    // This is the real bounding box (not an approximation) — a
    // flat-top hex tile's rightmost point sits at colStep*(col) + cardW
    // (colStep is only 0.75*cardW, so the last column's tile sticks
    // out further right than a naive `columns * colStep` guess would
    // suggest — that under-count was why the rightmost tiles used to
    // get clipped). Height accounts for whether the last row actually
    // has an odd (vertically-offset) column in it or not.
    // -----------------------------------------------------
    function dimsFor(cardWv, cardHv, colStepv, rowStepv, cols, count) {
        if (count <= 0 || cols <= 0) {
            return { width: 0, height: 0 };
        }

        const maxCol = Math.min(cols, count) - 1;
        const width = maxCol * colStepv + cardWv;

        const rows = Math.ceil(count / cols);
        const lastRowCount = count - (rows - 1) * cols;
        const lastRowHasOdd = lastRowCount > 1; // column index 1 (odd) present
        const height = (rows - 1) * rowStepv + (lastRowHasOdd ? rowStepv / 2 : 0) + cardHv;

        return { width: width, height: height };
    }

    function computeLayout(w, h, count) {
        if (count <= 0 || w <= 0 || h <= 0) {
            return { columns: 3, scale: 1.0 };
        }

        const widestColumns = Math.max(3, Math.floor(w / baseColStep));
        let bestColumns = widestColumns;
        let bestScale = 1.0;
        let foundFit = false;

        // Try every column count from 3 up to as many as could ever
        // fit at minimum size — fewer columns means taller/narrower
        // arrangement (more rows), more columns means shorter/wider.
        // Whichever gives the largest scale that still fits both
        // dimensions wins.
        for (let c = 3; c <= widestColumns; c++) {
            const d = dimsFor(baseCardW, baseCardH, baseColStep, baseRowStep, c, count);
            const scale = Math.min(w / d.width, h / d.height);

            if (scale >= 1.0) {
                const capped = Math.min(scale, maxGridScale);
                if (!foundFit || capped > bestScale) {
                    foundFit = true;
                    bestScale = capped;
                    bestColumns = c;
                }
            }
        }

        if (!foundFit) {
            // Even the widest column count needs shrinking below
            // minimum to fit — stay at minimum size and let the grid
            // scroll instead.
            bestColumns = widestColumns;
            bestScale = 1.0;
        }

        return { columns: bestColumns, scale: bestScale };
    }

    property var layoutResult: computeLayout(grid.width, grid.height, folderModel.count)
    property int gridColumns: layoutResult.columns
    property real gridScale: layoutResult.scale

    property real cardW: baseCardW * gridScale
    property real cardH: baseCardH * gridScale
    property real hSpacing: baseHSpacing * gridScale
    property real vSpacing: baseVSpacing * gridScale
    property real colStep: cardW * 0.75 + hSpacing
    property real rowStep: cardH + vSpacing

    // Actual on-screen footprint of the grid at its current scale —
    // used to center the honeycomb (equal gap on every side) instead
    // of always pinning it to the top-left.
    property var contentDims: dimsFor(cardW, cardH, colStep, rowStep, gridColumns, folderModel.count)

    // When true, tile hover events are ignored and only keyboard/click
    // drive selection. Starts true so a stray cursor position at launch
    // doesn't hijack the initial "currently applied wallpaper" pick.
    // Set true on any keypress (so ensureVisible()'s contentY animation,
    // which shifts tiles under a stationary cursor and would otherwise
    // spuriously re-trigger hover, doesn't fight the keyboard). Cleared
    // only by genuine mouse movement, detected via the screen-fixed
    // HoverHandler below (immune to inner content scrolling, unlike a
    // tile-local MouseArea whose own coordinate frame moves with it).
    property bool mouseSuspended: true
    // Continuously-updated real cursor position, from the screen-fixed
    // HoverHandler below (unaffected by inner content scrolling).
    property real lastMouseX: -1
    property real lastMouseY: -1
    // Snapshot of the cursor position at the moment we last entered
    // suspension (on open, and on every keypress). Resuming requires
    // moving more than resumeThreshold px away from THIS point — not
    // just "any event fired" — so any number of spurious re-fires
    // during window/layout settling (which all report the same
    // stationary position) can never falsely resume hover; only an
    // actual, measurable cursor movement can.
    property real suspendBaselineX: -1
    property real suspendBaselineY: -1
    property real resumeThreshold: 4

    HoverHandler {
        id: globalMouseTracker
        target: null
        onPointChanged: {
            const mx = point.position.x;
            const my = point.position.y;
            main.lastMouseX = mx;
            main.lastMouseY = my;
            if (main.suspendBaselineX < 0) {
                // First-ever report: nothing to compare against yet,
                // just establish the baseline at wherever the cursor
                // already happens to be.
                main.suspendBaselineX = mx;
                main.suspendBaselineY = my;
                return;
            }
            if (main.mouseSuspended) {
                const dx = mx - main.suspendBaselineX;
                const dy = my - main.suspendBaselineY;
                if (Math.sqrt(dx * dx + dy * dy) > main.resumeThreshold) {
                    main.mouseSuspended = false;
                }
            }
        }
    }

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

    // Full-res preview of the currently selected wallpaper, behind the
    // grid — swaps as you navigate since it's driven off
    // grid.selectedIndex. A dim overlay sits on top so the hexagon
    // tiles (and their borders) stay legible against it.
    Image {
        id: bgImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        source: (folderModel.count > 0 && grid.selectedIndex >= 0 && grid.selectedIndex < folderModel.count)
            ? "file://" + configs.cache_path.replace("~", Quickshell.env("HOME")) + folderModel.get(grid.selectedIndex, "fileName")
            : ""
    }

    Rectangle {
        anchors.fill: parent
        color: "#0a0b0d"
        opacity: 0.72
    }

    // -----------------------------------------------------
    // HONEYCOMB GRID
    // -----------------------------------------------------
    Flickable {
        id: grid
        anchors.fill: parent
        anchors.margins: 60
        focus: true
        clip: true
        interactive: false

        property int columns: main.gridColumns
        // Original folderModel index of the active wallpaper — the
        // pivot that the whole layout is rotated around. Set once on
        // open (see initTimer below) and left fixed after that, so
        // navigating away from it doesn't keep re-centering the grid
        // under your feet.
        property int centerAnchor: 0
        // Currently selected tile, also stored as an original
        // folderModel index (so folderModel.get()/activateCurrent()
        // can use it directly).
        property int selectedIndex: 0

        // Centers the honeycomb horizontally within the available width
        // when it's narrower than the viewport (few wallpapers) — equal
        // gap on both sides instead of all the slack collecting on one
        // side. There's no horizontal scrolling, so this is a fixed
        // offset (columns are always chosen to fit the width).
        property real offsetX: Math.max(0, (width - main.contentDims.width) / 2)

        // Vertical centering for when the honeycomb is smaller than the
        // viewport (few wallpapers, everything fits at once — no
        // scrolling needed at all). Equal gap top and bottom instead of
        // slack collecting on one side. Falls back to 0 once content is
        // taller than the viewport — in that case the view opens
        // scrolled all the way to the top (see initTimer) and only
        // scrolls further via ensureVisible() as you navigate down.
        property real offsetY: Math.max(0, (height - main.contentDims.height) / 2)

        contentWidth: Math.max(width, main.contentDims.width)
        contentHeight: Math.max(height, main.contentDims.height)

        Behavior on contentY {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // -----------------------------------------------------
        // Display-position mapping
        // -----------------------------------------------------
        // The grid is filled in "display position" order (0..count-1,
        // row-major, same as before) — but which wallpaper sits at
        // which display position is now a rotation of the file list,
        // not the file list itself. The rotation is chosen so that
        // centerAnchor (the active wallpaper) lands on centerCell()
        // (the grid's structurally-middle cell). Everything else keeps
        // its normal relative order around it, wrapping past the end
        // of the list back to the start.
        //
        // displayPos(originalIdx): where a given file's tile is drawn.
        // originalFromDisplay(pos): inverse — which file sits at a
        // given display position. Both are plain modular rotations of
        // each other, so no data is duplicated or reshuffled — this is
        // purely a layout-position lookup.

        // Which row/column the active wallpaper's anchor should land
        // on. Deliberately NOT the middle of the whole (possibly very
        // long) rotated list — that would put it below the fold for
        // large wallpaper counts, meaning you'd have to scroll up from
        // the initial view to see anything above it. Instead this
        // targets the middle of whatever fits on screen in one go, so
        // the view can always open at contentY 0 (a full, uncut top
        // row) with the anchor already comfortably centered within
        // that first screenful. Extra wallpapers are only ever reached
        // by scrolling down from there.
        function centerCell() {
            const count = folderModel.count;
            if (count <= 0) return 0;
            const totalRows = Math.ceil(count / columns);
            const visibleRows = Math.max(1, Math.floor(height / main.rowStep));
            const targetRow = Math.floor(Math.min(visibleRows, totalRows) / 2);
            const targetCol = Math.floor(columns / 2);
            let pos = targetRow * columns + targetCol;
            return Math.max(0, Math.min(pos, count - 1));
        }

        function displayPos(originalIdx) {
            const count = folderModel.count;
            if (count <= 0) return 0;
            const c = centerCell();
            return ((originalIdx - centerAnchor + c) % count + count) % count;
        }

        function originalFromDisplay(pos) {
            const count = folderModel.count;
            if (count <= 0) return 0;
            const c = centerCell();
            return ((pos - c + centerAnchor) % count + count) % count;
        }

        function colOfPos(p) { return p % columns; }
        function rowOfPos(p) { return Math.floor(p / columns); }

        // All display positions in a given column, top to bottom.
        function columnPositions(col) {
            let arr = [];
            for (let p = col; p < folderModel.count; p += columns) arr.push(p);
            return arr;
        }

        // Display-position bounds of the row a given position is in.
        function rowBoundsPos(p) {
            const r = rowOfPos(p);
            const rowStart = r * columns;
            const rowCount = Math.min(columns, folderModel.count - rowStart);
            return { start: rowStart, count: rowCount };
        }

        function moveLeft() {
            if (folderModel.count === 0) return;
            const dp = displayPos(selectedIndex);
            const col = colOfPos(dp);
            let newDp;
            if (col > 0) {
                newDp = dp - 1;
            } else {
                // Wrap: leftmost tile in the row -> rightmost tile in that row.
                const rb = rowBoundsPos(dp);
                newDp = rb.start + rb.count - 1;
            }
            selectedIndex = originalFromDisplay(newDp);
            ensureVisible();
        }

        function moveRight() {
            if (folderModel.count === 0) return;
            const dp = displayPos(selectedIndex);
            const rb = rowBoundsPos(dp);
            const col = colOfPos(dp);
            let newDp;
            if (col < rb.count - 1) {
                newDp = dp + 1;
            } else {
                // Wrap: rightmost tile in the row -> leftmost tile in that row.
                newDp = rb.start;
            }
            selectedIndex = originalFromDisplay(newDp);
            ensureVisible();
        }

        function moveUp(step) {
            if (folderModel.count === 0) return;
            const dp = displayPos(selectedIndex);
            const col = colOfPos(dp);
            const colArr = columnPositions(col);
            const pos = colArr.indexOf(dp);
            if (pos === -1) return;
            let next = (pos - step) % colArr.length;
            if (next < 0) next += colArr.length;
            // Wrap: top tile in the column -> bottom tile in that column.
            selectedIndex = originalFromDisplay(colArr[next]);
            ensureVisible();
        }

        function moveDown(step) {
            if (folderModel.count === 0) return;
            const dp = displayPos(selectedIndex);
            const col = colOfPos(dp);
            const colArr = columnPositions(col);
            const pos = colArr.indexOf(dp);
            if (pos === -1) return;
            let next = (pos + step) % colArr.length;
            // Wrap: bottom tile in the column -> top tile in that column.
            selectedIndex = originalFromDisplay(colArr[next]);
            ensureVisible();
        }

        function yForPos(p) {
            const c = colOfPos(p);
            const r = rowOfPos(p);
            return r * main.rowStep + (c % 2 === 1 ? main.rowStep / 2 : 0);
        }

        function ensureVisible() {
            const dp = displayPos(selectedIndex);
            const itemY = yForPos(dp) + offsetY;
            const itemBottom = itemY + main.cardH;
            if (itemY < contentY)
                contentY = Math.max(0, itemY);
            else if (itemBottom > contentY + height)
                contentY = Math.min(contentHeight - height, itemBottom - height);
        }

        function activateCurrent() {
            if (folderModel.count === 0) return;
            const path = folderModel.get(selectedIndex, "filePath");
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            Qt.quit();
        }

        Timer {
            id: initTimer
            interval: 50
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

                grid.centerAnchor = matchedIndex;
                grid.selectedIndex = matchedIndex;
                // Open at the very top of the content, never scrolled
                // down — centerCell() already placed the anchor within
                // that first screenful, so there's nothing above it to
                // miss, and everything else is reached by scrolling
                // down only.
                grid.contentY = 0;
            }
        }

        Connections {
            target: folderModel
            function onCountChanged() {
                initTimer.restart();
            }
        }

        Item {
            x: grid.offsetX
            y: grid.offsetY
            width: main.contentDims.width
            height: main.contentDims.height

            Repeater {
                model: folderModel

                delegate: Item {
                    id: tile
                    width: main.cardW
                    height: main.cardH

                    property int dispPos: grid.displayPos(index)
                    property int col: dispPos % grid.columns
                    property int row: Math.floor(dispPos / grid.columns)
                    property bool isCurrent: index === grid.selectedIndex

                    x: col * main.colStep
                    y: row * main.rowStep + (col % 2 === 1 ? main.rowStep / 2 : 0)
                    z: isCurrent ? 100 : 1
                    scale: isCurrent ? 1.06 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    // Hexagon path shared by the mask and the border outline
                    Shape {
                        id: hexMask
                        anchors.fill: parent
                        visible: false
                        ShapePath {
                            fillColor: "black"
                            strokeWidth: -1
                            startX: tile.width * 0.25; startY: 0
                            PathLine { x: tile.width * 0.75; y: 0 }
                            PathLine { x: tile.width;        y: tile.height * 0.5 }
                            PathLine { x: tile.width * 0.75; y: tile.height }
                            PathLine { x: tile.width * 0.25; y: tile.height }
                            PathLine { x: 0;                 y: tile.height * 0.5 }
                            PathLine { x: tile.width * 0.25; y: 0 }
                        }
                    }

                    Item {
                        id: cardContent
                        anchors.fill: parent
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            color: "#1e1e2e"
                        }

                        Text {
                            id: alt
                            text: "Loading..."
                            color: configs.border_color
                            anchors.centerIn: parent
                            font.pixelSize: 13
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

                    OpacityMask {
                        anchors.fill: parent
                        source: cardContent
                        maskSource: hexMask
                    }

                    // Selected-tile border: same hexagon outline, drawn on
                    // top, only stroked (no fill) so it traces the edge.
                    Shape {
                        anchors.fill: parent
                        opacity: tile.isCurrent ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        ShapePath {
                            fillColor: "transparent"
                            strokeWidth: 4
                            strokeColor: configs.border_color.length > 0 ? configs.border_color : "#ffffff"
                            startX: tile.width * 0.25; startY: 0
                            PathLine { x: tile.width * 0.75; y: 0 }
                            PathLine { x: tile.width;        y: tile.height * 0.5 }
                            PathLine { x: tile.width * 0.75; y: tile.height }
                            PathLine { x: tile.width * 0.25; y: tile.height }
                            PathLine { x: 0;                 y: tile.height * 0.5 }
                            PathLine { x: tile.width * 0.25; y: 0 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        // Moving the mouse over a tile selects/highlights
                        // it, mirroring keyboard navigation — no click
                        // needed just to preview a wallpaper. Deliberately
                        // using onPositionChanged instead of onEntered:
                        // onEntered can fire as soon as the window appears
                        // if the cursor already happens to be resting over
                        // this tile from before — with no real movement —
                        // which would hijack the initial "currently
                        // applied wallpaper" selection set by initTimer.
                        // onPositionChanged only fires on genuine mouse
                        // movement, never synthetically at startup.
                        onPositionChanged: {
                            if (main.mouseSuspended) return;
                            grid.selectedIndex = index;
                            grid.ensureVisible();
                        }

                        // Hover already made this tile current, so a
                        // single click is enough to apply it — no more
                        // "click to select, click again to apply".
                        onClicked: {
                            grid.forceActiveFocus();
                            grid.selectedIndex = index;
                            grid.activateCurrent();
                        }

                        // MouseArea intercepts wheel events by default,
                        // even with no onWheel handler wired up — that
                        // silently blocked grid's WheelHandler below.
                        // Explicitly un-accepting it lets it bubble up.
                        onWheel: function (wheel) {
                            wheel.accepted = false;
                        }
                    }
                }
            }
        }

        // Mouse-wheel scrolling — pans the view without changing which
        // tile is selected, same convention the other layouts use for
        // wheel-over-deck. j/k and the arrow keys still move selection.
        WheelHandler {
            target: null
            onWheel: function (event) {
                // TEMP DEBUG — remove once scrolling is confirmed working.
                // Run quickshell from a terminal and scroll over the grid:
                // if this line never prints, the wheel event isn't
                // reaching Qt at all (compositor/layer-shell axis-event
                // routing), not a QML logic problem — check Hyprland/
                // wlroots version and Quickshell's PanelWindow wheel
                // support. If it DOES print, the issue is purely in the
                // contentY math/clamping below.
                console.log("wheel fired, angleDelta.y =", event.angleDelta.y, "contentHeight-height =", grid.contentHeight - grid.height);
                grid.contentY = Math.max(0, Math.min(grid.contentHeight - grid.height, grid.contentY - event.angleDelta.y));
            }
        }

        Keys.onPressed: function (event) {
            // Any keyboard nav should own selection until the mouse
            // genuinely moves again — otherwise ensureVisible()'s
            // contentY animation shifts tiles under the (stationary)
            // cursor and hover immediately overwrites what you just
            // pressed. Re-anchor the baseline to wherever the cursor
            // currently is, so resuming requires real movement from
            // THIS point, not the stale launch-time point.
            main.mouseSuspended = true;
            main.suspendBaselineX = main.lastMouseX;
            main.suspendBaselineY = main.lastMouseY;

            const big = configs.number_of_pictures > 0 ? configs.number_of_pictures : 3;

            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                moveRight();
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                moveLeft();
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                moveUp(1);
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                moveDown(1);
            } else if (event.key === Qt.Key_U) {
                moveUp(big);
            } else if (event.key === Qt.Key_D) {
                moveDown(big);
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                activateCurrent();
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
