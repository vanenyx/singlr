pragma ComponentBehavior: Bound
import QtQuick
Item {
    id: shadow
    property real strength: 1
    // Two broad and contact layers; also render on the QPainter backend.
    Repeater {
        model: 18
        Rectangle {
            required property int index
            x: -index*2; y: 5-index*1.4
            width: parent.width+index*4; height: parent.height+index*3
            radius: 12+index*1.6
            color: Qt.rgba(0,0,0,(Theme.dark?.018:.0045)*shadow.strength)
        }
    }
    Rectangle { x:-1; y:2; width:parent.width+2; height:parent.height+2; radius:13; color:Qt.rgba(0,0,0,(Theme.dark?.13:.05)*shadow.strength) }
}
