pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

FocusScope {
    id: window
    focus: true
    enabled: SystemSettings.opened
    readonly property bool compactNavigation: width < 860
    readonly property bool editable: SystemSettings.available && SystemSettings.loaded && !SystemSettings.busy && !SystemSettings.trial
    readonly property var sections: [
        { id: "displays", title: "Мониторы", icon: "settings-monitor", hint: "экран разрешение масштаб яркость" },
        { id: "keyboard", title: "Клавиатура", icon: "keyboard", hint: "раскладка язык повтор ввод" },
        { id: "pointer", title: "Мышь и тачпад", icon: "settings-mouse", hint: "курсор скорость прокрутка касание" },
        { id: "audio", title: "Звук", icon: "volume", hint: "громкость вывод микрофон" },
        { id: "connections", title: "Подключения", icon: "wifi", hint: "сеть интернет bluetooth wifi" },
        { id: "lock", title: "Блокировка", icon: "settings-lock", hint: "пароль таймер dpms бездействие" },
        { id: "appearance", title: "Обои и рабочий стол", icon: "image", hint: "оформление тема обои виджеты эффекты" },
        { id: "notifications", title: "Уведомления", icon: "bell", hint: "тихий режим история не беспокоить" }
    ]
    property string displayedPage: SystemSettings.page
    readonly property bool fixedPage: displayedPage === "appearance" || displayedPage === "connections"
    readonly property var currentSection: sections.find(s => s.id === displayedPage) || sections[0]
    Component.onCompleted: displayedPage = SystemSettings.page
    property double now: Date.now()
    readonly property int remaining: SystemSettings.trial ? Math.max(0, Math.ceil((SystemSettings.trial.deadline - now) / 1000)) : 0
    Timer { interval: 1000; repeat: true; running: !!SystemSettings.trial; onTriggered: window.now = Date.now() }
    Connections { target: SystemSettings; function onTrialChanged(): void { window.now = Date.now(); } }
    Keys.onEscapePressed: SystemSettings.close()
    Connections {
        target: SystemSettings
        function onPageChanged(): void { pageTransition.restart(); }
    }
    SequentialAnimation {
        id: pageTransition
        NumberAnimation { target: pageHost; property: "opacity"; to: 0; duration: Theme.duration(70) }
        ScriptAction { script: { window.displayedPage = SystemSettings.page; pageHost.offset = 8; } }
        ParallelAnimation {
            NumberAnimation { target: pageHost; property: "opacity"; to: 1; duration: Theme.duration(180); easing.type: Easing.OutCubic }
            NumberAnimation { target: pageHost; property: "offset"; to: 0; duration: Theme.duration(220); easing.type: Easing.OutCubic }
        }
    }

    component Group: Rectangle {
        id: group
        property string heading: ""
        property bool bounded: false
        default property alias content: body.data
        radius: Theme.surfaceRadius
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.02)
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
        Layout.fillWidth: true
        implicitHeight: bounded ? 0 : body.implicitHeight + 36
        ColumnLayout {
            id: body
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18 }
            height: group.bounded ? Math.max(0, group.height - 36) : implicitHeight
            spacing: 18
            UiText { text: group.heading; visible: text !== ""; Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold }
        }
    }
    component Range: RowLayout {
        id: range
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.01
        property string suffix: ""
        property string hint: ""
        signal committed(real value)
        implicitWidth: 240
        spacing: 10
        PanelSlider {
            id: slider
            Layout.fillWidth: true
            from: range.from; to: range.to; stepSize: range.step; value: range.value
            Accessible.name: range.hint
            onPressedChanged: { if (!pressed) range.committed(value); }
            onMoved: { if (!pressed) range.committed(value); }
        }
        UiText { text: (range.step >= 1 ? Math.round(slider.value) : slider.value.toFixed(2)) + range.suffix; font.pixelSize: 11; color: Theme.muted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
    }

    WidgetSurface {
        anchors.fill: parent
        grainAlpha: 0.015
        topLeftRadius: SystemSettings.edge === "left" ? 0 : radius
        bottomLeftRadius: SystemSettings.edge === "left" ? 0 : radius
        topRightRadius: SystemSettings.edge === "right" ? 0 : radius
        bottomRightRadius: SystemSettings.edge === "right" ? 0 : radius
        readonly property color backdropColor: Qt.darker(Theme.surface, 1.12)
        color: Qt.rgba(backdropColor.r, backdropColor.g, backdropColor.b, 0.9)
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Rectangle {
                Layout.fillHeight: true; Layout.preferredWidth: window.compactNavigation ? 64 : 216
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.015)
                radius: 10
                topLeftRadius: SystemSettings.edge === "left" ? 0 : radius
                bottomLeftRadius: SystemSettings.edge === "left" ? 0 : radius
                ColumnLayout {
                    anchors { fill: parent; margins: window.compactNavigation ? 10 : 14 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 7; Layout.bottomMargin: 14; spacing: 10
                        PanelIcon { name: "home-settings"; tint: Theme.accent }
                        ColumnLayout {
                            visible: !window.compactNavigation
                            spacing: 2
                            UiText { text: "Настройки"; font.pixelSize: 17; font.weight: Font.DemiBold }
                            UiText { text: "Shoji Desktop"; font.pixelSize: 10; color: Theme.muted }
                        }
                    }
                    SettingsField {
                        id: search
                        visible: !window.compactNavigation
                        Layout.fillWidth: true; Layout.bottomMargin: 10
                        placeholderText: "Найти раздел"
                        Accessible.name: "Поиск раздела настроек"
                    }
                    Repeater {
                        model: window.sections
                        DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            text: window.compactNavigation ? "" : modelData.title; glyph: modelData.icon
                            hint: modelData.title
                            selected: SystemSettings.page === modelData.id
                            trailingIcon: ""
                            visible: (modelData.title + " " + modelData.hint).toLowerCase().includes(search.text.trim().toLowerCase())
                            onClicked: SystemSettings.page = modelData.id
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08) }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.margins: 24
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        UiText { text: window.currentSection.title; font.pixelSize: 23; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiText { text: "Параметры рабочего окружения"; color: Theme.muted; font.pixelSize: 11 }
                    }
                    SettingsActionButton { icon.source: Qt.resolvedUrl("icons/close.svg"); implicitWidth: 34; padding: 8; hint: "Закрыть настройки"; onClicked: SystemSettings.close() }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: trialContent.implicitHeight + 24
                    radius: 10; visible: !!SystemSettings.trial
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    ColumnLayout {
                        id: trialContent
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                        spacing: 8
                        UiText { text: "Изображение в порядке? Возврат прежних настроек через " + window.remaining + " с"; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: 12 }
                        RowLayout {
                            SettingsActionButton { text: "Оставить"; highlighted: true; enabled: !SystemSettings.busy; onClicked: SystemSettings.confirmDisplays() }
                            SettingsActionButton { text: "Вернуть прежние"; enabled: !SystemSettings.busy; onClicked: SystemSettings.revertDisplays() }
                        }
                    }
                }
                UiText {
                    visible: !SystemSettings.available && ["displays", "keyboard", "pointer"].includes(SystemSettings.page)
                    text: "Параметры ввода и дисплеев станут доступны после подключения модуля настроек в ShojiWM."
                    color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: 12
                }
                Item {
                    id: pageHost
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    property real offset: 0
                    transform: Translate { y: pageHost.offset }
                    enabled: !pageTransition.running
                    ScrollView {
                        id: scroll
                        anchors.fill: parent
                        visible: !window.fixedPage
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        Loader {
                            id: pageLoader
                            asynchronous: true
                            active: !window.fixedPage
                            width: scroll.availableWidth
                            sourceComponent: window.displayedPage === "keyboard" ? keyboardPage
                                : window.displayedPage === "pointer" ? pointerPage
                                : window.displayedPage === "audio" ? audioPage
                                : window.displayedPage === "lock" ? lockPage
                                : window.displayedPage === "notifications" ? notificationsPage : displaysPage
                            onSourceComponentChanged: { if (scroll.contentItem) scroll.contentItem.contentY = 0; }
                        }
                    }
                    Loader {
                        anchors.fill: parent
                        asynchronous: true
                        active: window.fixedPage
                        sourceComponent: window.displayedPage === "connections" ? connectionsPage : appearancePage
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiText {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11
                        text: SystemSettings.error || (SystemSettings.busy ? "Сохранение…" : SystemSettings.status)
                        color: SystemSettings.error ? Theme.danger : Theme.muted
                    }
                    SettingsActionButton { text: "Обновить"; implicitHeight: 30; font.pixelSize: 11; enabled: !SystemSettings.busy; onClicked: SystemSettings.refresh() }
                }
            }
        }
    }

    Component {
        id: keyboardPage
        ColumnLayout {
            spacing: 16
            Group {
                heading: "Раскладки"
                enabled: window.editable
                SettingsRow {
                    label: "Языки ввода"
                    description: "Порядок и вариант раскладок"
                    SettingsChoice {
                        hint: "Языки ввода"
                        model: [{ label: "EN + RU · международная", value: "us,ru|,ruintl_ru" }, { label: "EN + RU · стандартная", value: "us,ru|," },
                            { label: "EN", value: "us|" }]
                        currentIndex: model.findIndex(m => m.value === ((SystemSettings.values.keyboard || {}).layout + "|" + (SystemSettings.values.keyboard || {}).variant))
                        onActivated: { const parts = currentValue.split("|"); SystemSettings.updateInput("keyboard", { layout: parts[0], variant: parts[1] }); }
                    }
                }
                SettingsRow {
                    label: "Переключение раскладки"
                    SettingsChoice {
                        hint: "Переключение раскладки"
                        model: [{ label: "Alt + Shift", value: "grp:alt_shift_toggle" }, { label: "Ctrl + Shift", value: "grp:ctrl_shift_toggle" }, { label: "Caps Lock", value: "grp:caps_toggle" }]
                        currentIndex: model.findIndex(m => m.value === (SystemSettings.values.keyboard || {}).options)
                        onActivated: SystemSettings.updateInput("keyboard", { options: currentValue })
                    }
                }
                SettingsRow { label: "Сейчас активна"; description: "Состояние от композитора"; UiText { text: Keyboard.label || "—"; color: Theme.accent } }
            }
            Group {
                heading: "Повтор клавиш"
                enabled: window.editable
                SettingsRow {
                    label: "Скорость повтора"; description: "Символов в секунду при удержании"
                    Range { value: (SystemSettings.values.keyboard || {}).repeatRate || 60; from: 1; to: 100; step: 1; hint: "Скорость повтора"; onCommitted: value => SystemSettings.updateInput("keyboard", { repeatRate: Math.round(value) }) }
                }
                SettingsRow {
                    label: "Задержка повтора"; description: "Пауза перед первым повторением"
                    Range { value: (SystemSettings.values.keyboard || {}).repeatDelay || 250; from: 150; to: 1500; step: 50; suffix: " мс"; hint: "Задержка повтора"; onCommitted: value => SystemSettings.updateInput("keyboard", { repeatDelay: Math.round(value) }) }
                }
            }
            Group {
                heading: "Проверка ввода"
                SettingsField { Layout.fillWidth: true; placeholderText: "Попробуй раскладку и удержание клавиши"; Accessible.name: "Проверка клавиатуры" }
                UiText { text: "Текст из этого поля не сохраняется."; font.pixelSize: 11; color: Theme.muted }
            }
            Group {
                heading: "Подключённые клавиатуры"
                Repeater { model: SystemSettings.devices.filter(d => d.kind.keyboard); UiText { required property var modelData; text: modelData.name; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12 } }
            }
        }
    }
    Component {
        id: pointerPage
        ColumnLayout {
            spacing: 16
            Group {
                heading: "Мышь"
                enabled: window.editable
                SettingsRow {
                    label: "Скорость указателя"
                    Range { value: (SystemSettings.values.pointer || {}).pointerAccel || 0; from: -1; to: 1; step: 0.05; hint: "Скорость указателя"; onCommitted: value => SystemSettings.updateInput("pointer", { pointerAccel: value }) }
                }
                SettingsRow {
                    label: "Ускорение"
                    SettingsChoice {
                        hint: "Ускорение мыши"
                        model: [{ label: "Постоянная скорость", value: "flat" }, { label: "Адаптивное", value: "adaptive" }]
                        currentIndex: model.findIndex(m => m.value === (SystemSettings.values.pointer || {}).accelProfile)
                        onActivated: SystemSettings.updateInput("pointer", { accelProfile: currentValue })
                    }
                }
                SettingsRow { label: "Для левой руки"; SettingsToggle { hint: "Поменять кнопки мыши местами"; selected: !!(SystemSettings.values.pointer || {}).leftHanded; onRequested: selected => SystemSettings.updateInput("pointer", { leftHanded: selected }) } }
                SettingsRow { label: "Естественная прокрутка"; SettingsToggle { hint: "Естественная прокрутка мыши"; selected: !!(SystemSettings.values.pointer || {}).naturalScroll; onRequested: selected => SystemSettings.updateInput("pointer", { naturalScroll: selected }) } }
            }
            Group {
                heading: "Тачпад"
                enabled: window.editable && SystemSettings.devices.some(d => d.kind.touchpad)
                SettingsRow { label: "Касание для щелчка"; SettingsToggle { hint: "Касание для щелчка"; selected: !!(SystemSettings.values.touchpad || {}).tapToClick; onRequested: selected => SystemSettings.updateInput("touchpad", { tapToClick: selected }) } }
                SettingsRow { label: "Естественная прокрутка"; SettingsToggle { hint: "Естественная прокрутка тачпада"; selected: !!(SystemSettings.values.touchpad || {}).naturalScroll; onRequested: selected => SystemSettings.updateInput("touchpad", { naturalScroll: selected }) } }
                SettingsRow { label: "Отключать при наборе текста"; SettingsToggle { hint: "Отключать тачпад при наборе текста"; selected: !!(SystemSettings.values.touchpad || {}).disableWhileTyping; onRequested: selected => SystemSettings.updateInput("touchpad", { disableWhileTyping: selected }) } }
                SettingsRow {
                    label: "Скорость прокрутки"
                    Range { value: (SystemSettings.values.touchpad || {}).scrollFactor || 0.3; from: 0.1; to: 3; step: 0.1; hint: "Скорость прокрутки тачпада"; onCommitted: value => SystemSettings.updateInput("touchpad", { scrollFactor: value }) }
                }
            }
            UiText { text: "Тачпад не обнаружен"; visible: !SystemSettings.devices.some(d => d.kind.touchpad); color: Theme.muted; font.pixelSize: 12 }
        }
    }
    Component { id: audioPage; ControlCentre { stats: ({}); sectionMode: "audio"; active: window.visible && SystemSettings.opened } }
    Component { id: connectionsPage; ConnectionsSettings { active: window.visible && SystemSettings.opened } }
    Component {
        id: lockPage
        ColumnLayout {
            spacing: 16
            Group {
                heading: "Обои и предпросмотр локскрина"
                WallpaperSettings { Layout.fillWidth: true; lockScreen: true }
            }
            Group {
                heading: "Бездействие"
                enabled: SystemSettings.loaded && !SystemSettings.busy
                SettingsRow {
                    label: "Блокировать через"
                    description: "Без движения мыши и нажатий клавиш"
                    SettingsChoice {
                        hint: "Таймер блокировки"
                        model: [1, 5, 10, 15, 20, 30, 60, 120].map(n => ({ label: n + " мин", value: n }))
                        currentIndex: model.findIndex(m => m.value === SystemSettings.lockMinutes)
                        onActivated: SystemSettings.setIdle(currentValue, SystemSettings.dimMinutes)
                    }
                }
                SettingsRow {
                    label: "Гасить мониторы ещё через"
                    description: "После блокировки · пробуждение мышью или клавишей"
                    SettingsChoice {
                        hint: "Таймер DPMS после блокировки"
                        model: [1, 2, 5, 10, 15, 30, 60].map(n => ({ label: n + " мин", value: n }))
                        currentIndex: model.findIndex(m => m.value === SystemSettings.dimMinutes)
                        onActivated: SystemSettings.setIdle(SystemSettings.lockMinutes, currentValue)
                    }
                }
                UiText { text: "Всего до выключения мониторов: " + (SystemSettings.lockMinutes + SystemSettings.dimMinutes) + " мин"; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
            Group {
                heading: "Разблокировка"
                SettingsRow { label: "Вызов экрана блокировки"; UiText { text: "Super + L"; color: Theme.accent; font.pixelSize: 12 } }
                SettingsRow { label: "Питание мониторов"; UiText { text: Lock.dpmsAvailable ? "DPMS доступен" : "DPMS недоступен"; color: Theme.muted; font.pixelSize: 12 } }
                UiText { text: "Пароль — пароль пользователя системы. Раскладка отображается на каждом экране блокировки."; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: Theme.muted }
            }
        }
    }
    Component {
        id: appearancePage
        ColumnLayout {
            id: appearance
            property bool extras: false
            spacing: 12
            RowLayout {
                spacing: 8
                SettingsActionButton { text: "Обои"; highlighted: !appearance.extras; onClicked: appearance.extras = false }
                SettingsActionButton { text: "Оформление и эффекты"; highlighted: appearance.extras; onClicked: appearance.extras = true }
            }
            Group {
                heading: "Обои рабочего стола"
                bounded: true
                Layout.fillHeight: true
                visible: !appearance.extras
                DesktopWallpaperSettings {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                    compact: window.height < 900
                }
            }
            ScrollView {
                id: extrasScroll
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: appearance.extras
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: extrasScroll.availableWidth
                    spacing: 16
                    Group {
                        heading: "Наше оформление"
                        UiText { text: "Mocha / Mauve"; font.pixelSize: 22; font.weight: Font.DemiBold; color: Theme.accent }
                        UiText { text: "Noto Sans · матовые поверхности · мелкое статичное зерно"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        RowLayout {
                            spacing: 8
                            Repeater { model: [Theme.surface, Theme.raised, Theme.hover, Theme.accent, Theme.ink]; Rectangle { required property color modelData; width: 36; height: 26; radius: 7; color: modelData; border.width: 1; border.color: Theme.line } }
                        }
                    }
                    Group {
                        heading: "Обои, эффекты и виджеты"
                        Repeater {
                            model: Quickshell.screens
                            SettingsRow {
                                id: appearanceRow
                                required property var modelData
                                label: modelData.name
                                description: modelData.width + " × " + modelData.height
                                SettingsActionButton { text: "Обои и виджеты"; onClicked: { const name = appearanceRow.modelData.name; SystemSettings.close(); Wallpapers.toggle(name); } }
                                SettingsActionButton { text: "Эффекты"; onClicked: { const name = appearanceRow.modelData.name; SystemSettings.close(); ScreenShaders.toggle(name); } }
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: notificationsPage
        ColumnLayout {
            spacing: 16
            Group {
                heading: "Режим уведомлений"
                SettingsRow {
                    label: "Не беспокоить"
                    description: "До перезапуска оболочки · история продолжает пополняться"
                    SettingsToggle { hint: "Не беспокоить"; selected: Notifications.quiet; onRequested: selected => Notifications.quiet = selected }
                }
                SettingsRow { label: "В истории"; UiText { text: Notifications.count + " / " + Notifications.historyLimit; color: Theme.muted; font.pixelSize: 12 } }
                SettingsActionButton { text: "Очистить историю"; enabled: Notifications.count > 0; onClicked: Notifications.clearAll() }
            }
        }
    }
    Component {
        id: displaysPage
        ColumnLayout {
            id: displayPage
            spacing: 16
            property string selected: ""
            readonly property var output: SystemSettings.outputs.find(o => o.name === selected) || null
            property var draft: ({ mode: "extend", resolution: "best", position: "auto", scale: 1 })
            readonly property var modes: [{ label: "Рекомендуемый", value: "best" }].concat(output ? output.availableModes.map(m => ({ label: m.width + " × " + m.height + " · " + Number(m.refreshRate.toFixed(2)) + " Гц", value: JSON.stringify(m) })) : [])
            function resetDraft() {
                draft = SystemSettings.copy((SystemSettings.values.outputs || {})[selected] || { mode: "extend", resolution: "best", position: "auto", scale: 1 });
            }
            function patch(value) { draft = Object.assign({}, draft, value); }
            onSelectedChanged: resetDraft()
            Component.onCompleted: { selected = SystemSettings.outputs.length ? SystemSettings.outputs[0].name : ""; }
            Connections {
                target: SystemSettings
                function onSnapshotChanged(): void {
                    if (!SystemSettings.outputs.some(o => o.name === displayPage.selected))
                        displayPage.selected = SystemSettings.outputs.length ? SystemSettings.outputs[0].name : "";
                }
            }
            Group {
                heading: "Расположение экранов"
                implicitHeight: 240
                Item {
                    id: monitorMap
                    Layout.fillWidth: true; Layout.preferredHeight: 155
                    readonly property var screens: SystemSettings.outputs.filter(o => o.resolution && o.scale > 0)
                    readonly property real minX: screens.length ? Math.min(...screens.map(o => o.position.x)) : 0
                    readonly property real minY: screens.length ? Math.min(...screens.map(o => o.position.y)) : 0
                    readonly property real totalWidth: screens.length ? Math.max(...screens.map(o => o.position.x + o.resolution.width / o.scale)) - minX : 1
                    readonly property real totalHeight: screens.length ? Math.max(...screens.map(o => o.position.y + o.resolution.height / o.scale)) - minY : 1
                    readonly property real fit: Math.min((width - 20) / Math.max(1, totalWidth), (height - 20) / Math.max(1, totalHeight))
                    Repeater {
                        model: SystemSettings.outputs.filter(o => o.resolution)
                        SettingsActionButton {
                            required property var modelData
                            width: Math.max(1, modelData.resolution.width / modelData.scale * monitorMap.fit - 4)
                            height: Math.max(1, modelData.resolution.height / modelData.scale * monitorMap.fit - 4)
                            x: (monitorMap.width - monitorMap.totalWidth * monitorMap.fit) / 2 + (modelData.position.x - monitorMap.minX) * monitorMap.fit + 2
                            y: (monitorMap.height - monitorMap.totalHeight * monitorMap.fit) / 2 + (modelData.position.y - monitorMap.minY) * monitorMap.fit + 2
                            text: modelData.name
                            highlighted: displayPage.selected === modelData.name
                            hint: "Выбрать монитор " + modelData.name
                            onClicked: displayPage.selected = modelData.name
                        }
                    }
                }
            }
            Group {
                heading: "Параметры монитора"
                enabled: window.editable && !!displayPage.output
                SettingsRow {
                    label: "Монитор"
                    description: displayPage.output ? displayPage.output.description || displayPage.output.model || "" : "Мониторы не обнаружены"
                    SettingsChoice {
                        hint: "Выбор монитора"
                        model: SystemSettings.outputs.map(o => ({ label: o.name, value: o.name }))
                        currentIndex: model.findIndex(m => m.value === displayPage.selected)
                        onActivated: displayPage.selected = currentValue
                    }
                }
                SettingsRow {
                    label: "Разрешение и частота"
                    SettingsChoice {
                        hint: "Режим монитора"
                        model: displayPage.modes
                        currentIndex: model.findIndex(m => m.value === (displayPage.draft.resolution === "best" ? "best" : JSON.stringify(displayPage.draft.resolution)))
                        onActivated: displayPage.patch({ resolution: currentValue === "best" ? "best" : JSON.parse(currentValue) })
                    }
                }
                SettingsRow {
                    label: "Масштаб интерфейса"
                    SettingsChoice {
                        hint: "Масштаб монитора"
                        model: [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3].map(n => ({ label: Math.round(n * 100) + "%", value: n }))
                        currentIndex: model.findIndex(m => m.value === displayPage.draft.scale)
                        onActivated: displayPage.patch({ scale: currentValue })
                    }
                }
                SettingsRow {
                    label: "Размещение"
                    SettingsChoice {
                        hint: "Размещение монитора"
                        model: [{ label: "Автоматически", value: "auto" }, { label: "Задать координаты", value: "manual" }]
                        currentIndex: displayPage.draft.position === "auto" ? 0 : 1
                        onActivated: displayPage.patch({ position: currentValue === "auto" ? "auto" : SystemSettings.copy(displayPage.output.position) })
                    }
                }
                SettingsRow {
                    visible: displayPage.draft.position !== "auto"
                    label: "Положение X / Y"
                    description: "Логические пиксели относительно других экранов"
                    SettingsField {
                        id: posX
                        Layout.preferredWidth: 98
                        text: displayPage.draft.position === "auto" ? "0" : String(displayPage.draft.position.x)
                        validator: IntValidator { bottom: -32768; top: 32768 }
                        Accessible.name: "Положение монитора X"
                        onEditingFinished: { if (acceptableInput) displayPage.patch({ position: { x: Number(text), y: displayPage.draft.position.y } }); }
                    }
                    SettingsField {
                        id: posY
                        Layout.preferredWidth: 98
                        text: displayPage.draft.position === "auto" ? "0" : String(displayPage.draft.position.y)
                        validator: IntValidator { bottom: -32768; top: 32768 }
                        Accessible.name: "Положение монитора Y"
                        onEditingFinished: { if (acceptableInput) displayPage.patch({ position: { x: displayPage.draft.position.x, y: Number(text) } }); }
                    }
                }
                RowLayout {
                    SettingsActionButton {
                        text: "Применить к монитору"; highlighted: true
                        enabled: displayPage.draft.position === "auto" || (posX.acceptableInput && posY.acceptableInput)
                        onClicked: {
                            const next = SystemSettings.copy(displayPage.draft);
                            if (next.position !== "auto") next.position = { x: Number(posX.text), y: Number(posY.text) };
                            SystemSettings.applyDisplay(displayPage.selected, next);
                        }
                    }
                    SettingsActionButton { text: "Сбросить правки"; onClicked: displayPage.resetDraft() }
                }
                UiText { text: "Без подтверждения за 20 секунд вернутся прежние параметры. Изменения не выключают мониторы."; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11 }
            }
            Group {
                heading: "Яркость выбранного монитора"
                Brightness { id: backlight; connector: displayPage.selected }
                SettingsActionButton {
                    text: backlight.busy ? "Чтение яркости…" : "Прочитать яркость"
                    enabled: !!displayPage.output && !backlight.busy
                    onClicked: backlight.query("get", 0)
                }
                UiText {
                    text: "DDC/CI опрашивается только по кнопке, чтобы открытие раздела и выбор экрана не обращались к мониторам."
                    Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11
                }
                SettingsRow {
                    label: displayPage.selected || "Монитор"
                    Range { from: 0; to: 100; step: 1; suffix: "%"; value: backlight.value; enabled: backlight.available && !backlight.busy; hint: "Яркость монитора"; onCommitted: value => backlight.query("set", Math.round(value)) }
                }
                UiText { text: backlight.busy ? "Чтение яркости…" : backlight.error; visible: text !== ""; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
        }
    }
}
