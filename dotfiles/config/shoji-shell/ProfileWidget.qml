pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root
    implicitWidth: 340
    implicitHeight: details.y + content.implicitHeight + 12
    width: implicitWidth
    height: implicitHeight
    property string displayName: Quickshell.env("USER")
    property string avatarUrl: ""
    // Add your own tags and public links locally.
    readonly property var tags: []
    readonly property var socials: []

    Process {
        running: true
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("system-profile.py").toString().replace("file://", ""))]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (typeof value.name !== "string" || !value.name.trim()
                            || typeof value.avatar !== "string" || !value.avatar.startsWith("file:///")) return;
                    root.displayName = value.name;
                    root.avatarUrl = value.avatar;
                } catch (error) { console.warn("Could not read system profile"); }
            }
        }
    }

    WidgetSurface {
        anchors { fill: parent; topMargin: 38 }
    }
    Rectangle {
        anchors.centerIn: avatar
        width: avatar.width + 8; height: width
        radius: width / 2
        color: Qt.darker(Theme.surface, 1.12)
    }
    ClippingRectangle {
        id: avatar
        anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        width: 68; height: 68
        radius: width / 2
        color: Theme.raised
        border.width: 2
        border.color: Theme.accent
        Image {
            id: portrait
            anchors.fill: parent
            source: root.avatarUrl
            sourceSize: Qt.size(136, 136)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
        }
        UiText {
            anchors.centerIn: parent
            visible: portrait.status !== Image.Ready
            text: root.displayName.slice(0, 1).toUpperCase()
            font.pixelSize: 24; font.weight: Font.DemiBold
            color: Theme.accent
        }
        Accessible.role: Accessible.Graphic
        Accessible.name: "Аватар: " + root.displayName
    }
    UiText {
        id: name
        anchors { top: avatar.bottom; topMargin: 6; left: parent.left; right: parent.right; margins: 16 }
        horizontalAlignment: Text.AlignHCenter
        text: root.displayName
        font.pixelSize: 20; font.weight: Font.DemiBold
        color: Theme.ink
    }
    Rectangle {
        anchors { top: name.bottom; topMargin: 10; left: parent.left; right: parent.right; margins: 16 }
        height: 1
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
    }
    Flickable {
        id: details
        anchors { top: name.bottom; topMargin: 21; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16; bottomMargin: 12 }
        contentWidth: width
        contentHeight: content.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 3 }
        Column {
            id: content
            width: details.width
            spacing: 10
            Column {
                id: badges
                width: parent.width
                spacing: 5
                Repeater {
                    model: [[root.tags[0], root.tags[2]], [root.tags[1]], [root.tags[4]], [root.tags[3]]]
                    delegate: Row {
                        id: tagRow
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Repeater {
                            model: tagRow.modelData
                            delegate: Rectangle {
                                id: badge
                                required property var modelData
                                readonly property color tint: modelData.color
                                width: Math.min(badges.width, badgeLabel.implicitWidth + 16)
                                height: badgeLabel.implicitHeight + 8
                                radius: 6
                                color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
                                UiText {
                                    id: badgeLabel
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    text: badge.modelData.text
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: badge.tint
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 1
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
            }
            Column {
                width: parent.width
                Repeater {
                    model: root.socials
                    delegate: Button {
                        id: social
                        required property var modelData
                        width: parent.width
                        implicitHeight: 26
                        padding: 5
                        hoverEnabled: true
                        Accessible.role: Accessible.Link
                        Accessible.name: modelData.label + ": " + modelData.handle
                        onClicked: Qt.openUrlExternally(modelData.url)
                        background: Rectangle {
                            radius: 5
                            color: social.hovered ? Theme.raised : "transparent"
                            border.width: social.visualFocus ? 1 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            UiText {
                                Layout.fillWidth: true
                                text: social.modelData.handle
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: social.hovered ? Theme.accent : Theme.ink
                            }
                            UiText {
                                text: social.modelData.label
                                font.pixelSize: 10; color: Theme.muted
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
