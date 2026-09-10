import QtQuick  
import Quickshell  
import Quickshell.Wayland  
  
PanelWindow {  
    id: root  
      
    property var targetScreen: Quickshell.screens[0]
    property string tempPath: ""

    screen: targetScreen

    anchors { 
        left: true  
        right: true  
        top: true  
        bottom: true  
    }  
  
    exclusionMode: ExclusionMode.Ignore  
    WlrLayershell.layer: WlrLayer.Overlay  
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand  
    // A stable namespace lets Hyprland exclude this transient capture surface
    // from the normal layer open/close animations.
    WlrLayershell.namespace: "hyprquickframe"
  
    Image {  
        source: (root.visible && root.tempPath) ? "file://" + root.tempPath : ""
        anchors.fill: parent  
        z: -1
    }  
}
