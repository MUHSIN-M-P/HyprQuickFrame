import QtQuick

Item {
    id: root
    anchors.fill: parent

    property string tempPath: ""

    Image {
        source: (root.visible && root.tempPath) ? "file://" + root.tempPath : ""
        anchors.fill: parent
        z: -1
        fillMode: Image.Stretch
        asynchronous: false
        cache: false
    }
}
