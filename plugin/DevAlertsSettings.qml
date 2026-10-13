import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "devAlerts"

    ToggleSetting {
        settingKey: "peekEnabled"
        label: "Island peek"
        description: "Expand the pill briefly to show new issues, due reminders and tracked-PR activity"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "peekSeconds"
        label: "Peek duration"
        description: "How long the expanded pill stays open"
        options: [
            {label: "4 seconds", value: "4"},
            {label: "6 seconds", value: "6"},
            {label: "10 seconds", value: "10"}
        ]
        defaultValue: "6"
    }

    SelectionSetting {
        settingKey: "refreshSeconds"
        label: "Refresh interval"
        description: "How often the widget re-reads devalert state"
        options: [
            {label: "15 seconds", value: "15"},
            {label: "30 seconds", value: "30"},
            {label: "60 seconds", value: "60"}
        ]
        defaultValue: "30"
    }
}
