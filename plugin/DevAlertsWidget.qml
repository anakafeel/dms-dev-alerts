import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Backend: ~/.local/bin/devalert (see repo README). Args go through "$@",
    // so user text is never interpolated into the shell string.
    readonly property var backend: ["sh", "-c", "exec \"$HOME/.local/bin/devalert\" \"$@\" 2>&1", "devalert"]

    property var status: ({ "issues": [], "reminders": [], "tracked": [], "counts": {} })
    readonly property int newIssues: status.counts.new_issues || 0
    readonly property int dueReminders: status.counts.due_reminders || 0
    readonly property int unreadTracked: status.counts.unread_tracked || 0
    readonly property int total: newIssues + dueReminders + unreadTracked

    readonly property bool peekEnabled: pluginData.peekEnabled ?? true
    readonly property int peekSeconds: parseInt(pluginData.peekSeconds ?? "6")
    readonly property int refreshSeconds: parseInt(pluginData.refreshSeconds ?? "30")

    property bool loaded: false
    property string peekText: ""
    property string peekIcon: "notifications_active"
    property bool peeking: false
    property int cmdSeq: 0
    property int currentTab: 0

    function refresh() {
        Proc.runCommand("devAlerts.status", root.backend.concat(["status"]), (out, code) => {
            if (code !== 0)
                return;
            let next;
            try {
                next = JSON.parse(out);
            } catch (e) {
                return;
            }
            if (root.loaded)
                root.maybePeek(root.status, next);
            root.status = next;
            root.loaded = true;
        }, 100);
    }

    // Each call gets its own id: Proc debounces calls that share one.
    function run(args, okMessage) {
        root.cmdSeq++;
        Proc.runCommand("devAlerts.cmd." + root.cmdSeq, root.backend.concat(args), (out, code) => {
            if (code !== 0)
                ToastService.showError(I18n.tr("Dev Alerts"), out.trim());
            else if (okMessage)
                ToastService.showInfo(okMessage);
            root.refresh();
        }, 0);
    }

    function maybePeek(prev, next) {
        if (!root.peekEnabled)
            return;
        const known = new Set(prev.issues.map(i => i.url));
        const fresh = next.issues.filter(i => !known.has(i.url) && i.status === "new");
        const wasUnread = new Set(prev.tracked.filter(t => t.unread).map(t => t.url));
        const news = next.tracked.filter(t => t.unread && !wasUnread.has(t.url));
        const wasDue = new Set(prev.reminders.filter(r => r.fired).map(r => r.id));
        const due = next.reminders.filter(r => r.fired && !wasDue.has(r.id));
        if (due.length) {
            root.showPeek("alarm", due[0].text);
        } else if (news.length) {
            root.showPeek("forum", news[0].repo + "#" + news[0].num + " · " + (news[0].news || news[0].state));
        } else if (fresh.length) {
            root.showPeek("bug_report", fresh.length === 1 ? fresh[0].repo + " · " + fresh[0].title : fresh.length + " new issues · " + fresh[0].repo);
        }
    }

    function showPeek(icon, text) {
        root.peekIcon = icon;
        root.peekText = text;
        root.peeking = true;
        peekTimer.restart();
    }

    function openUrl(url) {
        Qt.openUrlExternally(url);
        root.closePopout();
    }

    function formatDue(epoch) {
        const d = new Date(epoch * 1000);
        const now = new Date();
        const sameDay = d.toDateString() === now.toDateString();
        return Qt.formatDateTime(d, sameDay ? "'today' h:mm AP" : "ddd MMM d, h:mm AP");
    }

    Timer {
        interval: root.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: peekTimer
        interval: root.peekSeconds * 1000
        onTriggered: root.peeking = false
    }

    pillRightClickAction: () => root.run(["tick", "--poll"], I18n.tr("Checked tracked issues"))

    horizontalBarPill: Component {
        // BasePill draws the background and padding and sizes itself from
        // implicitWidth, so this pill matches the other bar widgets.
        Item {
            id: pill
            implicitWidth: root.peeking ? Math.min(356, peekRow.implicitWidth) : compactRow.implicitWidth
            implicitHeight: root.widgetThickness
            clip: true

            // Spring-like overshoot, the "island" grow/shrink.
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            Row {
                id: compactRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                opacity: root.peeking ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.dueReminders ? "alarm" : root.unreadTracked ? "forum" : "notifications_active"
                    size: root.iconSize
                    color: root.total ? Theme.primary : Theme.surfaceText
                    filled: root.total > 0
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.total > 0
                    text: root.total
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
            }

            Row {
                id: peekRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: Theme.spacingS
                opacity: root.peeking ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.peekIcon
                    size: root.iconSize
                    color: Theme.primary
                    filled: true
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 320)
                    text: root.peekText
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: root.widgetThickness
            height: col.implicitHeight + Theme.spacingM * 2
            radius: width / 2
            color: Theme.surfaceContainerHigh

            Column {
                id: col
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "notifications_active"
                    size: root.iconSize
                    color: root.total ? Theme.primary : Theme.surfaceText
                    filled: root.total > 0
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.total > 0
                    text: root.total
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }
    }

    popoutWidth: 460
    popoutHeight: 560

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: I18n.tr("Dev Alerts")
            detailsText: root.newIssues + " new issues · " + root.dueReminders + " due · " + root.unreadTracked + " unread"
            showCloseButton: true

            readonly property real bodyHeight: root.popoutHeight - headerHeight - detailsHeight - Theme.spacingXL

            Column {
                width: parent.width
                spacing: Theme.spacingS

                DankTabBar {
                    id: tabs
                    width: parent.width
                    tabHeight: 40
                    currentIndex: root.currentTab
                    model: [
                        { "text": I18n.tr("Issues") + (root.newIssues ? " " + root.newIssues : ""), "icon": "bug_report" },
                        { "text": I18n.tr("Reminders"), "icon": "alarm" },
                        { "text": I18n.tr("Tracking") + (root.unreadTracked ? " " + root.unreadTracked : ""), "icon": "forum" }
                    ]
                    onTabClicked: index => root.currentTab = index
                }

                // ---- Issues ----
                ListView {
                    id: issuesList
                    visible: root.currentTab === 0
                    width: parent.width
                    height: popout.bodyHeight - tabs.height
                    clip: true
                    spacing: Theme.spacingXS
                    model: root.status.issues

                    StyledText {
                        x: (issuesList.width - width) / 2
                        y: (issuesList.height - height) / 2
                        visible: issuesList.count === 0
                        text: I18n.tr("No issues yet. gfi-watch checks hourly.")
                        color: Theme.surfaceVariantText
                    }

                    delegate: StyledRect {
                        required property var modelData
                        width: ListView.view.width
                        height: issueCol.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius
                        color: issueMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                        MouseArea {
                            id: issueMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl(modelData.url)
                        }

                        Column {
                            id: issueCol
                            anchors.left: parent.left
                            anchors.right: issueActions.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingS
                            spacing: 2

                            StyledText {
                                width: parent.width
                                text: modelData.title
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: modelData.status === "new" ? Font.Medium : Font.Normal
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                text: modelData.repo + "  ★" + (modelData.stars >= 1000 ? Math.round(modelData.stars / 1000) + "k" : modelData.stars) + "  · " + modelData.labels.join(", ")
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        Row {
                            id: issueActions
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                iconName: modelData.status === "saved" ? "bookmark_added" : "bookmark"
                                iconColor: modelData.status === "saved" ? Theme.primary : Theme.surfaceText
                                tooltipText: modelData.status === "saved" ? I18n.tr("Unsave") : I18n.tr("Save")
                                onClicked: root.run(["issue", modelData.url, modelData.status === "saved" ? "new" : "saved"])
                            }

                            DankActionButton {
                                iconName: "close"
                                tooltipText: I18n.tr("Dismiss")
                                onClicked: root.run(["issue", modelData.url, "dismissed"])
                            }
                        }
                    }
                }

                // ---- Reminders ----
                Column {
                    id: remindTab
                    visible: root.currentTab === 1
                    width: parent.width
                    spacing: Theme.spacingS

                    property string repeat: ""

                    DankTextField {
                        id: remindText
                        width: parent.width
                        placeholderText: I18n.tr("Remind me to…")
                        leftIconName: "edit_note"
                        onAccepted: remindWhen.forceActiveFocus()
                    }

                    Row {
                        id: whenRow
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: remindWhen
                            width: parent.width - repeatBtn.width - addBtn.width - Theme.spacingS * 2
                            placeholderText: I18n.tr("tomorrow 17:00, fri 9am, +2 hours")
                            leftIconName: "schedule"
                            onAccepted: addBtn.clicked()
                        }

                        DankButton {
                            id: repeatBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: remindTab.repeat || I18n.tr("once")
                            iconName: "repeat"
                            onClicked: {
                                const order = ["", "daily", "weekly"];
                                remindTab.repeat = order[(order.indexOf(remindTab.repeat) + 1) % order.length];
                            }
                        }

                        DankButton {
                            id: addBtn
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "add"
                            text: I18n.tr("Add")
                            onClicked: {
                                const t = remindText.text.trim();
                                const w = remindWhen.text.trim();
                                if (!t || !w)
                                    return;
                                const args = ["remind", "add", t, w];
                                if (remindTab.repeat)
                                    args.push("--repeat", remindTab.repeat);
                                root.run(args, I18n.tr("Reminder added"));
                                remindText.text = "";
                                remindWhen.text = "";
                            }
                        }
                    }

                    ListView {
                        id: remindersList
                        width: parent.width
                        height: popout.bodyHeight - tabs.height - remindText.height - whenRow.height - Theme.spacingS * 3
                        clip: true
                        spacing: Theme.spacingXS
                        model: root.status.reminders

                        StyledText {
                            x: (remindersList.width - width) / 2
                            y: (remindersList.height - height) / 2
                            visible: remindersList.count === 0
                            text: I18n.tr("No reminders")
                            color: Theme.surfaceVariantText
                        }

                        delegate: StyledRect {
                            required property var modelData
                            readonly property bool overdue: modelData.due * 1000 <= Date.now()
                            width: ListView.view.width
                            height: 52
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            border.width: overdue ? 1 : 0
                            border.color: Theme.error

                            DankIcon {
                                id: remIcon
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.repeat ? "repeat" : "alarm"
                                size: Theme.iconSizeSmall
                                color: overdue ? Theme.error : Theme.primary
                            }

                            Column {
                                anchors.left: remIcon.right
                                anchors.right: doneBtn.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: parent.width
                                    text: modelData.text
                                    elide: Text.ElideRight
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: root.formatDue(modelData.due) + (modelData.repeat ? " · " + modelData.repeat : "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: overdue ? Theme.error : Theme.surfaceVariantText
                                }
                            }

                            DankActionButton {
                                id: doneBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "check"
                                tooltipText: modelData.repeat ? I18n.tr("Delete repeating reminder") : I18n.tr("Done")
                                onClicked: root.run(["remind", "done", modelData.id])
                            }
                        }
                    }
                }

                // ---- Tracking ----
                Column {
                    visible: root.currentTab === 2
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        id: trackRow
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: trackUrl
                            width: parent.width - trackBtn.width - Theme.spacingS
                            placeholderText: I18n.tr("GitHub issue or PR URL")
                            leftIconName: "link"
                            onAccepted: trackBtn.clicked()
                        }

                        DankButton {
                            id: trackBtn
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "add"
                            text: I18n.tr("Track")
                            onClicked: {
                                const u = trackUrl.text.trim();
                                if (!u)
                                    return;
                                root.run(["track", "add", u], I18n.tr("Tracking"));
                                trackUrl.text = "";
                            }
                        }
                    }

                    ListView {
                        id: trackedList
                        width: parent.width
                        height: popout.bodyHeight - tabs.height - trackRow.height - Theme.spacingS * 2
                        clip: true
                        spacing: Theme.spacingXS
                        model: root.status.tracked

                        StyledText {
                            x: (trackedList.width - width) / 2
                            y: (trackedList.height - height) / 2
                            visible: trackedList.count === 0
                            text: I18n.tr("Paste a PR/issue URL to watch it for new comments")
                            color: Theme.surfaceVariantText
                        }

                        delegate: StyledRect {
                            required property var modelData
                            width: ListView.view.width
                            height: trackCol.implicitHeight + Theme.spacingS * 2
                            radius: Theme.cornerRadius
                            color: trackMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: modelData.unread ? 1 : 0
                            border.color: Theme.primary

                            MouseArea {
                                id: trackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.unread)
                                        root.run(["track", "read", modelData.url]);
                                    root.openUrl(modelData.url);
                                }
                            }

                            DankIcon {
                                id: kindIcon
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.kind === "pr" ? (modelData.state === "merged" ? "merge" : "call_split") : (modelData.state === "open" ? "radio_button_unchecked" : "check_circle")
                                size: Theme.iconSizeSmall
                                color: modelData.state === "open" ? Theme.success : modelData.state === "merged" ? Theme.primary : Theme.surfaceVariantText
                            }

                            Column {
                                id: trackCol
                                anchors.left: kindIcon.right
                                anchors.right: rmBtn.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: modelData.title || modelData.url
                                    elide: Text.ElideRight
                                    font.weight: modelData.unread ? Font.Bold : Font.Normal
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    width: parent.width
                                    text: (modelData.repo || "") + "#" + (modelData.num || "") + " · " + (modelData.state || "?") + " · " + (modelData.comments || 0) + " comments"
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    width: parent.width
                                    visible: !!modelData.news
                                    text: modelData.news || ""
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                            }

                            DankActionButton {
                                id: rmBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "close"
                                tooltipText: I18n.tr("Stop tracking")
                                onClicked: root.run(["track", "rm", modelData.url])
                            }
                        }
                    }
                }
            }
        }
    }
}
