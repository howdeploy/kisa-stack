pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

FocusScope {
    id: root
    focus: true
    readonly property real expandedWidth: Math.min(440, width * 0.55)
    readonly property real collapsedWidth: Math.min(220, width * 0.28)
    readonly property real cardHeight: Math.min(210, height * 0.28)

    function step(direction) {
        if (!ScreenShaders.ready || !carousel.count) return;
        const index = Math.max(0, Math.min(carousel.count - 1, carousel.currentIndex + direction));
        ScreenShaders.preview(ScreenShaders.items[index].id);
    }
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: ScreenShaders.cancel()
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: ScreenShaders.apply()
    Keys.onEnterPressed: ScreenShaders.apply()

    Rectangle { anchors.fill: parent; color: "#60000000" }
    MouseArea { anchors.fill: parent; onClicked: ScreenShaders.cancel() }
    Text {
        anchors.centerIn: parent
        visible: ScreenShaders.items.length === 0 && ScreenShaders.error !== ""
        text: ScreenShaders.error
        color: Theme.danger
        font.family: Theme.font
        font.pixelSize: 14
    }
    ListView {
        id: carousel
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: root.cardHeight + 32
        model: ScreenShaders.items
        orientation: ListView.Horizontal
        spacing: 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        preferredHighlightBegin: (width - root.expandedWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin + root.expandedWidth
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 220
        currentIndex: Math.max(0, ScreenShaders.items.findIndex(item => item.id === ScreenShaders.previewId))
        enabled: ScreenShaders.ready && !ScreenShaders.finishing
        function centerSelection() {
            if (currentIndex >= 0 && count) positionViewAtIndex(currentIndex, ListView.Center);
        }
        Component.onCompleted: Qt.callLater(centerSelection)
        onCountChanged: Qt.callLater(centerSelection)
        onWidthChanged: Qt.callLater(centerSelection)
        onMovementEnded: {
            if (ScreenShaders.ready && currentIndex >= 0 && currentIndex < ScreenShaders.items.length)
                ScreenShaders.preview(ScreenShaders.items[currentIndex].id);
        }
        WheelHandler {
            target: null
            onWheel: event => {
                root.step((event.angleDelta.y || event.angleDelta.x) > 0 ? -1 : 1);
                event.accepted = true;
            }
        }
        delegate: Item {
            id: card
            required property int index
            required property var modelData
            readonly property bool selected: ListView.isCurrentItem
            // Stable cells keep the selected center fixed while its preview expands.
            width: root.expandedWidth
            height: carousel.height
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.title + ". " + modelData.description
            Accessible.selected: selected
            Accessible.onPressAction: ScreenShaders.preview(card.modelData.id)
            Item {
                anchors.centerIn: parent
                width: card.selected ? root.expandedWidth : root.collapsedWidth
                height: root.cardHeight
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, -0.12, 0, root.cardHeight * 0.06,
                                         0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
                Rectangle { anchors.fill: parent; color: Theme.surface }
                Image {
                    anchors.fill: parent
                    source: ScreenShaders.thumbnails[card.modelData.id] || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: card.selected ? Theme.accent : Theme.line
                    border.width: card.selected ? 2 : 1
                }
            }
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
                width: Math.max(0, (card.selected ? root.expandedWidth : root.collapsedWidth) - 24)
                spacing: 4
                Text {
                    width: parent.width
                    text: card.modelData.title
                    color: Theme.ink; font.family: Theme.font; font.pixelSize: card.selected ? 18 : 14; font.weight: Font.DemiBold
                    style: Text.Outline; styleColor: Theme.surface
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: card.selected && (ScreenShaders.error !== "" || ScreenShaders.thumbnailError !== "")
                    text: ScreenShaders.error || ScreenShaders.thumbnailError
                    color: Theme.danger; font.family: Theme.font; font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { ScreenShaders.preview(card.modelData.id); root.forceActiveFocus(); }
                onDoubleClicked: ScreenShaders.apply()
            }
        }
    }
}
