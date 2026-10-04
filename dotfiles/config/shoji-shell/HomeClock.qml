pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "HomeMascots.js" as Art

Item {
    id: root
    property bool showSeconds: false
    implicitWidth: 852
    implicitHeight: 228
    readonly property string digits: Qt.formatDateTime(clock.date, showSeconds ? "hhmmss" : "hhmm")
    property var faces: []
    onDigitsChanged: faces = Art.choose(digits, faces)
    Component.onCompleted: faces = Art.choose(digits, faces)
    property int tick: 0
    SystemClock { id: clock; precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    Timer { interval: 100; repeat: true; running: root.visible; onTriggered: root.tick = (root.tick + 1) % 72 }
    Accessible.role: Accessible.Clock
    Accessible.name: Qt.formatDateTime(clock.date, root.showSeconds ? "hh:mm:ss" : "hh:mm")
    Row {
        anchors.centerIn: parent
        spacing: 0
        scale: Math.min(1, root.width / width)
        Repeater {
            model: root.showSeconds ? 6 : 4
            delegate: Item {
                id: cell
                required property int index
                readonly property int digit: root.faces[index] ? root.faces[index].digit : Number(root.digits[index])
                readonly property int variant: root.faces[index] ? root.faces[index].variant : index >= 2 && index < 4 ? 2 : 0
                property int displayedDigit: digit
                property int displayedVariant: variant
                property bool ready: false
                readonly property bool separator: index === 2 || index === 4
                width: 174 + (separator ? 26 : 0)
                height: root.height
                Component.onCompleted: { displayedDigit = digit; displayedVariant = variant; ready = true; }
                onDigitChanged: { if (ready) flip.restart(); }
                onVariantChanged: { if (ready) flip.restart(); }
                Column {
                    visible: cell.separator
                    width: 26
                    y: parent.height * 0.44
                    spacing: 10
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
                        shadowVerticalOffset: 2; shadowBlur: 0.8; blurMax: 8
                    }
                    Repeater {
                        model: 2
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 10; height: 10; radius: 5
                            color: "white"; border.width: 1; border.color: "#8011111b"
                        }
                    }
                }
                Item {
                    id: sprite
                    x: cell.separator ? 26 : 0
                    width: 174; height: root.height
                    clip: true
                    transform: Rotation {
                        id: hinge
                        origin.x: sprite.width / 2; origin.y: sprite.height / 2
                        axis { x: 1; y: 0; z: 0 }
                    }
                    HomeMascot {
                        id: mascot
                        anchors.fill: parent
                        digit: cell.displayedDigit
                        variant: cell.displayedVariant
                        tick: root.tick + cell.index * 13 + cell.displayedDigit * 7
                    }
                    UiText {
                        anchors.centerIn: parent
                        visible: !mascot.ready
                        text: cell.displayedDigit
                        font.pixelSize: 68; font.weight: Font.Bold; color: Theme.accent
                    }
                }
                SequentialAnimation {
                    id: flip
                    NumberAnimation { target: hinge; property: "angle"; from: 0; to: 90; duration: 140; easing.type: Easing.InCubic }
                    ScriptAction { script: { cell.displayedDigit = cell.digit; cell.displayedVariant = cell.variant; } }
                    NumberAnimation { target: hinge; property: "angle"; from: -90; to: 0; duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
