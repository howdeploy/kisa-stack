pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

ColumnLayout {
    id: panel
    required property var stats
    property bool active: visible
    property string section: ""
    property var promptNetwork: null
    property string status: ""
    property bool outputsExpanded: false
    spacing: 12

    Brightness { id: backlight; active: panel.active }
    Binding { target: Media; property: "active"; value: panel.active }

    function gib(bytes) { return (bytes / 1073741824).toFixed(1); }
    function join(network) {
        status = "";
        if (network.connected) { network.disconnect(); return; }
        if (!network.known && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe) {
            promptNetwork = network;
            return;
        }
        network.connect();
    }
    function submitPassword() {
        if (!promptNetwork || password.text === "") return;
        promptNetwork.connectWithPsk(password.text);
        password.clear();
        promptNetwork = null;
    }
    onVisibleChanged: { if (!visible) { password.clear(); promptNetwork = null; section = ""; outputsExpanded = false; } }
    Binding {
        target: Services.wifi
        property: "scannerEnabled"
        value: true
        when: Services.wifi !== null && panel.active && panel.section === "wifi" && Networking.wifiEnabled
        restoreMode: Binding.RestoreBindingOrValue
    }
    Instantiator {
        model: Services.wifi ? Services.wifi.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason): void {
                panel.status = "Не удалось подключиться к «" + modelData.name + "». Проверь пароль и сигнал.";
                if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
                    panel.promptNetwork = modelData;
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ConnectionTile {
            text: "Wi-Fi"; glyph: "wifi"
            subtitle: Services.wifiLabel
            Layout.fillWidth: true; Layout.preferredWidth: 1
            connected: Networking.wifiEnabled && Services.wifi !== null
            expanded: panel.section === "wifi"
            onClicked: panel.section = panel.section === "wifi" ? "" : "wifi"
        }
        ConnectionTile {
            text: "Bluetooth"; glyph: "bluetooth"
            subtitle: Services.btLabel
            Layout.fillWidth: true; Layout.preferredWidth: 1
            connected: Services.adapter !== null && Services.adapter.enabled
            expanded: panel.section === "bluetooth"
            onClicked: panel.section = panel.section === "bluetooth" ? "" : "bluetooth"
        }
    }

    DeviceList {
        expanded: panel.section === "wifi"
        animate: panel.active
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "Беспроводные сети"; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
            DeviceRow {
                implicitHeight: 30
                text: Networking.wifiEnabled ? "Выключить" : "Включить"
                enabled: Services.wifi !== null && Networking.wifiHardwareEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
        Repeater {
            model: Networking.wifiEnabled && Services.wifi ? Services.wifi.networks.values.slice().sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength) : []
            DeviceRow {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name || "Скрытая сеть"
                subtitle: (modelData.stateChanging ? "Изменение подключения…" : modelData.connected ? "Подключено" : "Доступна")
                    + " · Сигнал " + Math.round(modelData.signalStrength * 100) + "%"
                glyph: "wifi"
                enabled: !modelData.stateChanging && modelData.name !== ""
                selected: modelData.connected
                onClicked: panel.join(modelData)
            }
        }
        UiText {
            Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted
            visible: Services.wifi !== null && Networking.wifiEnabled && Services.wifi.networks.values.length === 0
            text: "Поиск сетей…"
        }
        ColumnLayout {
            Layout.fillWidth: true; visible: panel.promptNetwork !== null
            UiText { text: panel.promptNetwork ? "Пароль · " + panel.promptNetwork.name : ""; Layout.fillWidth: true }
            TextField {
                id: password
                Layout.fillWidth: true; echoMode: TextInput.Password
                placeholderText: "Пароль сети"
                color: Theme.ink; selectionColor: Theme.accent
                Accessible.name: "Пароль Wi-Fi"
                background: Rectangle { radius: 10; color: Theme.raised; border.color: password.activeFocus ? Theme.accent : Theme.line }
                onAccepted: panel.submitPassword()
            }
            RowLayout {
                ActionButton { text: "Подключиться"; highlighted: true; onClicked: panel.submitPassword() }
                ActionButton { text: "Отмена"; onClicked: { password.clear(); panel.promptNetwork = null; } }
            }
        }
        UiText { text: panel.status; visible: text !== ""; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }

    DeviceList {
        expanded: panel.section === "bluetooth"
        animate: panel.active
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "Устройства"; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
            DeviceRow {
                implicitHeight: 30
                enabled: Services.adapter !== null
                text: Services.adapter && Services.adapter.enabled ? "Выключить" : "Включить"
                onClicked: Services.adapter.enabled = !Services.adapter.enabled
            }
        }
        Repeater {
            model: Bluetooth.devices.values.filter(d => d.paired || d.connected)
            DeviceRow {
                required property var modelData
                Layout.fillWidth: true
                enabled: Services.adapter !== null && Services.adapter.enabled
                    && modelData.state !== BluetoothDeviceState.Connecting && modelData.state !== BluetoothDeviceState.Disconnecting
                text: modelData.name || modelData.address
                subtitle: (modelData.state === BluetoothDeviceState.Connecting ? "Подключение…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "Отключение…"
                    : modelData.connected ? "Подключено" : "Не подключено")
                    + (modelData.batteryAvailable ? " · Заряд " + Math.round(modelData.battery * 100) + "%" : "")
                selected: modelData.connected
                glyph: "bluetooth"
                hint: modelData.connected ? "Отключить " + modelData.name : "Подключить " + modelData.name
                onClicked: modelData.connected = !modelData.connected
            }
        }
        DeviceRow {
            text: "Добавить устройство"; glyph: "plus"
            Layout.fillWidth: true; enabled: Services.adapter !== null && Services.adapter.enabled
            onClicked: Quickshell.execDetached(["bluedevil-wizard"])
        }
    }

    UiText { text: "Звук и экран"; color: Theme.muted; font.pixelSize: 11; font.weight: Font.Medium; Layout.topMargin: 4 }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: soundContent.implicitHeight + 24
        radius: 8; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035)
        border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
        ColumnLayout {
            id: soundContent
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                UiText { text: "Яркость"; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                ActionButton {
                    text: backlight.connector; hint: "Выбрать монитор"
                    icon.source: Qt.resolvedUrl("icons/chevron-right.svg"); icon.width: 14; icon.height: 14
                    implicitHeight: 24; font.pixelSize: 10; padding: 4
                    enabled: !backlight.busy && Quickshell.screens.length > 1
                    onClicked: {
                        const screens = Quickshell.screens;
                        const at = screens.findIndex(s => s.name === backlight.connector);
                        backlight.connector = screens[(at + 1) % screens.length].name;
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                PanelIcon { name: "brightness"; Layout.preferredWidth: 28 }
                PanelSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    value: backlight.value / 100
                    enabled: backlight.available && !backlight.busy
                    Accessible.name: "Яркость монитора " + backlight.connector
                    onPressedChanged: { if (!pressed && enabled) backlight.query("set", Math.round(value * 100)); }
                    Keys.onReleased: event => { if (enabled) backlight.query("set", Math.round(value * 100)); }
                }
                UiText { text: backlight.busy ? "…" : backlight.available ? Math.round(brightnessSlider.value * 100) + "%" : "—"; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
            }
            UiText { text: backlight.error; visible: !backlight.busy && text !== ""; color: Theme.muted; font.pixelSize: 10; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                ActionButton {
                    icon.source: Qt.resolvedUrl(Services.muted ? "icons/muted.svg" : "icons/volume.svg")
                    hint: Services.muted ? "Включить звук" : "Выключить звук"
                    implicitWidth: 28; implicitHeight: 28; padding: 4
                    enabled: Services.sink !== null && Services.sink.audio !== null
                    onClicked: Services.sink.audio.muted = !Services.sink.audio.muted
                }
                PanelSlider {
                    Layout.fillWidth: true
                    value: Services.sink && Services.sink.audio ? Services.sink.audio.volume : 0
                    enabled: Services.sink !== null && Services.sink.audio !== null
                    Accessible.name: "Громкость"
                    onMoved: Services.sink.audio.volume = value
                }
                UiText { text: Services.volume + "%"; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
            }
            DeviceRow {
                Layout.fillWidth: true
                text: Services.sink ? Services.sink.description || Services.sink.name : "Нет аудиовыхода"
                subtitle: "Вывод звука"
                glyph: "volume"
                hint: "Выбрать вывод звука"
                trailingIcon: "chevron-right"
                trailingRotation: panel.outputsExpanded ? 90 : 0
                onClicked: panel.outputsExpanded = !panel.outputsExpanded
            }
            DeviceList {
                expanded: panel.outputsExpanded
                animate: panel.active
                Repeater {
                    model: Services.outputs
                    DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.description || modelData.name
                        glyph: "volume"
                        selected: modelData === Services.sink
                        onClicked: { Pipewire.preferredDefaultAudioSink = modelData; panel.outputsExpanded = false; }
                    }
                }
                DeviceRow { text: "Микрофон и звук приложений…"; trailingIcon: "chevron-right"; Layout.fillWidth: true; onClicked: Quickshell.execDetached(["pavucontrol"]) }
            }
        }
    }

    UiText { text: "Медиа"; color: Theme.muted; font.pixelSize: 11; font.weight: Font.Medium; Layout.topMargin: 4 }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: mediaContent.implicitHeight + 24
        radius: 8; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035)
        border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
        ColumnLayout {
            id: mediaContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 6
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 12; color: Theme.surface
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; visible: Media.art !== ""; sourceSize.width: 92; sourceSize.height: 92 }
                    PanelIcon { anchors.centerIn: parent; name: "headphones"; tint: Theme.accent; visible: Media.art === "" }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    UiText { text: Media.usable ? Media.title || Media.player.identity : "Ничего не играет"; font.weight: Font.DemiBold; font.pixelSize: 12; Layout.fillWidth: true }
                    UiText { text: Media.usable ? Media.artist || Media.player.identity : "Открой музыку или видео"; color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                }
                RowLayout {
                    spacing: 2
                    ActionButton { icon.source: Qt.resolvedUrl("icons/previous.svg"); hint: "Предыдущий трек"; implicitWidth: 26; implicitHeight: 30; padding: 4; enabled: Media.usable && Media.player.canGoPrevious; onClicked: Media.previous() }
                    ActionButton { icon.source: Qt.resolvedUrl(Media.playing ? "icons/pause.svg" : "icons/play.svg"); hint: Media.playing ? "Пауза" : "Воспроизвести"; implicitWidth: 32; implicitHeight: 32; padding: 6; highlighted: true; enabled: Media.usable && Media.player.canTogglePlaying; onClicked: Media.toggle() }
                    ActionButton { icon.source: Qt.resolvedUrl("icons/next.svg"); hint: "Следующий трек"; implicitWidth: 26; implicitHeight: 30; padding: 4; enabled: Media.usable && Media.player.canGoNext; onClicked: Media.next() }
                }
            }
            PanelSlider {
                Layout.fillWidth: true; implicitHeight: 20
                value: Media.length > 0 ? Media.position / Media.length : 0
                enabled: Media.usable && Media.player.canSeek && Media.length > 0
                Accessible.name: "Позиция воспроизведения"
                onMoved: Media.seekFraction(value)
            }
            RowLayout {
                Layout.fillWidth: true
                UiText { text: Media.clock(Media.position); font.pixelSize: 9; color: Theme.muted; Layout.fillWidth: true }
                UiText { text: Media.clock(Media.length); font.pixelSize: 9; color: Theme.muted }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        UiText { text: "Ресурсы"; color: Theme.muted; font.pixelSize: 11; font.weight: Font.Medium; Layout.fillWidth: true }
        UiText { text: panel.stats.uptime === undefined ? "" : "В работе " + Math.floor(panel.stats.uptime / 3600) + " ч"; color: Theme.muted; font.pixelSize: 11 }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        StatCard { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "CPU"; detail: "Процессор"; reading: panel.stats.cpu === undefined ? "…" : panel.stats.cpu + "%"; fraction: (panel.stats.cpu || 0) / 100 }
        StatCard {
            Layout.fillWidth: true; Layout.preferredWidth: 1; label: "RAM"
            reading: panel.stats.ramTotal ? Math.round(panel.stats.ramUsed / panel.stats.ramTotal * 100) + "%" : "…"
            detail: panel.stats.ramTotal ? panel.gib(panel.stats.ramUsed) + " / " + panel.gib(panel.stats.ramTotal) + " GiB" : "Память"
            fraction: panel.stats.ramTotal ? panel.stats.ramUsed / panel.stats.ramTotal : 0
        }
        StatCard {
            Layout.fillWidth: true; Layout.preferredWidth: 1; label: "GPU"; visible: !!panel.stats.gpu
            reading: panel.stats.gpu ? panel.stats.gpu.load + "%" : "…"
            detail: panel.stats.gpu ? panel.stats.gpu.temperature + "°C · " + (panel.stats.gpu.used / 1024).toFixed(1) + " GiB" : "Видеокарта"
            fraction: panel.stats.gpu ? panel.stats.gpu.load / 100 : 0
        }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: diskContent.implicitHeight + 28
        radius: 8; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035)
        border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
        ColumnLayout {
            id: diskContent
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            spacing: 14
            UiText { text: "Накопители"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.muted }
            Repeater {
                // A fixed delegate count preserves the bars across snapshots.
                model: (panel.stats.disks || []).length
                Meter {
                    required property int index
                    readonly property var sample: (panel.stats.disks || [])[index]
                    Layout.fillWidth: true; label: sample ? sample.label : ""
                    reading: sample && sample.mounted ? panel.gib(sample.used) + " / " + panel.gib(sample.total) + " GiB" : "Не подключён"
                    fraction: sample && sample.mounted ? sample.used / sample.total : 0
                }
            }
        }
    }
}
