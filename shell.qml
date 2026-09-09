import Quickshell
import QtQuick

// Top-level Scope allows loading PanelWindow dynamically without rendering white artifacts
Scope {
    id: root

    // Change this string to switch layouts:
    // "shell-coverflow.qml" or "shell-classic.qml"
//-----------------------------------------------------------------------------------------

    property string activeLayout: "shell-classic.qml"

    // property string activeLayout: "shell-bottom-dock.qml"

    // property string activeLayout: "shell-coverflow.qml"
    // property string activeLayout: "shell-coverflow-clear.qml"
    // property string activeLayout: "shell-coverflow-minimal.qml"

    // -------Floating version with blurred background and widgets-------
    // property string activeLayout: "shell-floating.qml"
    // property string activeLayout: "shell-floating-center-reflection.qml"
    // property string activeLayout: "shell-floating-clean.qml"

    // -------Floating version with clear backround image and widgets-------
    // property string activeLayout: "shell-floating-clear.qml"
    // property string activeLayout: "shell-floating-clear-clean.qml"

    // -------Floating version with no backround blur and widgets-------
    // property string activeLayout: "shell-floating-minimal.qml"
    // property string activeLayout: "shell-floating-minimal-clean.qml"

    // property string activeLayout: "shell-hexcomb.qml"

    // property string activeLayout: "shell-grid-view.qml"
    
    Loader {
        active: true
        source: Qt.resolvedUrl(root.activeLayout)
    }
}
