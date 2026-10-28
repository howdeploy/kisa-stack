pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

ColumnLayout {
    id: panel
    property bool active: visible
    readonly property bool wifiOn: Services.wifi !== null && Networking.wifiEnabled
    readonly property bool bluetoothOn: Services.adapter !== null && Services.adapter.enabled
    readonly property var networks: wifiOn ? Services.wifi.networks.values.slice().sort((a, b) =>
        Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength) : []
    readonly property var devices: bluetoothOn ? Bluetooth.devices.values.filter(d => d.paired || d.connected)
        .sort((a, b) => Number(b.connected) - Number(a.connected) || (a.name || a.address).localeCompare(b.name || b.address)) : []
    property var promptNetwork: null
    property string status: ""
    spacing: 14

    function cancelPrompt() { password.clear(); promptNetwork = null; }
    function join(network) {
        if (!active || !wifiOn || network.stateChanging || !network.name) return;
        status = "";
        cancelPrompt();
        if (network.connected) network.disconnect();
        else if (!network.known && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe)
            promptNetwork = network;
        else network.connect();
    }
    function submitPassword() {
        if (!active || !wifiOn || !promptNetwork || !password.text) return;
        const network = promptNetwork;
        const secret = password.text;
        cancelPrompt();
        network.connectWithPsk(secret);
    }
    function toggleDevice(device) {
        if (!active || !bluetoothOn || device.state === BluetoothDeviceState.Connecting
                || device.state === BluetoothDeviceState.Disconnecting) return;
        device.connected = !device.connected;
    }
    onActiveChanged: { if (!active) { cancelPrompt(); status = ""; } }
    onWifiOnChanged: { if (!wifiOn) cancelPrompt(); }
    onPromptNetworkChanged: {
        password.clear();
        if (promptNetwork) Qt.callLater(() => { if (panel.active && panel.promptNetwork) password.forceActiveFocus(); });
    }
    Binding {
        target: Services.wifi
        property: "scannerEnabled"
        value: true
        when: Services.wifi !== null && panel.active && panel.wifiOn
        restoreMode: Binding.RestoreBindingOrValue
    }
    Instantiator {
        model: Services.wifi ? Services.wifi.networks.values : []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason): void {
                if (!panel.active) return;
                panel.status = "Не удалось подключиться к «" + modelData.name + "». Проверь пароль и сигнал.";
                if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
                    panel.promptNetwork = modelData;
            }
        }
    }

    component Section: Rectangle {
        default property alias content: body.data
        Layout.fillWidth: true; Layout.fillHeight: true
        Layout.preferredHeight: 1; Layout.minimumHeight: 0
        radius: Theme.surfaceRadius
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.02)
        border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
        ColumnLayout { id: body; anchors { fill: parent; margins: 16 } spacing: 12 }
    }
    component ConnectionRow: Rectangle {
        id: row
        property string title: ""
        property string subtitle: ""
        property string glyph: ""
        property bool connected: false
        property bool busy: false
        signal requested()
        implicitHeight: 60
        radius: 8
        color: connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.055) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.duration(180) } }
        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 12
            PanelIcon { name: row.glyph; tint: row.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                UiText { text: row.title; Layout.fillWidth: true; font.pixelSize: 13 }
                UiText { text: row.subtitle; Layout.fillWidth: true; font.pixelSize: 11; color: row.connected ? Theme.accent : Theme.muted }
            }
            SettingsActionButton {
                text: row.busy ? "Подождите…" : row.connected ? "Отключить" : "Подключить"
                hint: text + " «" + row.title + "»"
                enabled: row.enabled && !row.busy
                onClicked: row.requested()
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05) }
    }

    Section {
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            PanelIcon { name: "wifi"; tint: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                UiText { text: "Wi-Fi"; font.pixelSize: 16; font.weight: Font.DemiBold }
                UiText {
                    text: !Services.wifi ? "Адаптер не обнаружен" : !Networking.wifiHardwareEnabled ? "Отключён аппаратно"
                        : panel.wifiOn ? "Сети поблизости · " + panel.networks.length : "Выключен"
                    color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true
                }
            }
            SettingsToggle {
                hint: "Включить Wi-Fi"; selected: panel.wifiOn
                enabled: Services.wifi !== null && Networking.wifiHardwareEnabled
                onRequested: selected => Networking.wifiEnabled = selected
            }
        }
        ListView {
            id: wifiList
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
            clip: true; spacing: 2; cacheBuffer: 0; reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: panel.networks
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: ConnectionRow {
                required property var modelData
                width: wifiList.width
                title: modelData.name || "Скрытая сеть"
                subtitle: (modelData.stateChanging ? "Изменение подключения…" : modelData.connected ? "Подключено" : modelData.known ? "Сохранена" : "Доступна")
                    + " · Сигнал " + Math.round(modelData.signalStrength * 100) + "%"
                glyph: "wifi"; connected: modelData.connected; busy: modelData.stateChanging
                enabled: modelData.name !== ""
                onRequested: panel.join(modelData)
            }
            UiText {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                visible: wifiList.count === 0
                text: !Services.wifi ? "Wi-Fi адаптер недоступен" : panel.wifiOn ? "Поиск доступных сетей…" : "Включи Wi-Fi для просмотра сетей"
                color: Theme.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
        }
        ColumnLayout {
            visible: panel.promptNetwork !== null
            Layout.fillWidth: true; spacing: 8
            UiText { text: panel.promptNetwork ? "Пароль для «" + panel.promptNetwork.name + "»" : ""; font.pixelSize: 12; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                SettingsField {
                    id: password
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Пароль сети"
                    Accessible.name: "Пароль Wi-Fi"
                    onAccepted: panel.submitPassword()
                }
                SettingsActionButton { text: "Подключиться"; highlighted: true; enabled: password.text !== ""; onClicked: panel.submitPassword() }
                SettingsActionButton { text: "Отмена"; onClicked: panel.cancelPrompt() }
            }
        }
        UiText { text: panel.status; visible: text !== ""; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: 11 }
    }
    Section {
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            PanelIcon { name: "bluetooth"; tint: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                UiText { text: "Bluetooth"; font.pixelSize: 16; font.weight: Font.DemiBold }
                UiText {
                    text: !Services.adapter ? "Адаптер не обнаружен" : panel.bluetoothOn ? "Сохранённые устройства · " + panel.devices.length : "Выключен"
                    color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true
                }
            }
            SettingsActionButton {
                text: "Добавить устройство"; enabled: panel.bluetoothOn
                onClicked: Quickshell.execDetached(["bluedevil-wizard"])
            }
            SettingsToggle {
                hint: "Включить Bluetooth"; selected: panel.bluetoothOn
                enabled: Services.adapter !== null
                onRequested: selected => Services.adapter.enabled = selected
            }
        }
        ListView {
            id: bluetoothList
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
            clip: true; spacing: 2; cacheBuffer: 0; reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: panel.devices
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: ConnectionRow {
                required property var modelData
                width: bluetoothList.width
                title: modelData.name || modelData.address
                subtitle: (modelData.state === BluetoothDeviceState.Connecting ? "Подключение…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "Отключение…" : modelData.connected ? "Подключено" : "Не подключено")
                    + (modelData.batteryAvailable ? " · Заряд " + Math.round(modelData.battery * 100) + "%" : "")
                glyph: "bluetooth"; connected: modelData.connected
                busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                onRequested: panel.toggleDevice(modelData)
            }
            UiText {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                visible: bluetoothList.count === 0
                text: !Services.adapter ? "Bluetooth адаптер недоступен" : panel.bluetoothOn
                    ? "Нет сохранённых устройств. Используй «Добавить устройство» для сопряжения." : "Включи Bluetooth для просмотра устройств"
                color: Theme.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
        }
    }
}
