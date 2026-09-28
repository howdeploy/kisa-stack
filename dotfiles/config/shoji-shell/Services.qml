pragma Singleton
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

Singleton {
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var network: wifi ? wifi.networks.values.find(n => n.connected) || null : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool wifiEnabled: Networking.wifiEnabled && wifi !== null
    readonly property bool bluetoothEnabled: adapter !== null && adapter.enabled
    readonly property var bluetoothConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string wifiIcon: !wifiEnabled ? "wifi-off" : network ? "wifi" : "wifi-disconnected"
    readonly property string bluetoothIcon: bluetoothEnabled ? "bluetooth" : "bluetooth-off"
    readonly property string wifiLabel: !wifi ? "Нет Wi-Fi адаптера" : !Networking.wifiEnabled ? "Wi-Fi выключен" : network ? network.name : "Не подключён"
    readonly property string btLabel: !adapter ? "Нет адаптера" : !adapter.enabled ? "Выключен" : bluetoothConnected.length > 0 ? bluetoothConnected.map(d => d.name || d.address).join(", ") : "Включён"
    PwObjectTracker { objects: [Services.sink].concat(Services.outputs).filter(n => n !== null) }
}
