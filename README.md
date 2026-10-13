# Dev Alerts

A DankMaterialShell (DMS) bar widget plugin for developers who track open source work. It shows a compact pill in the bar that expands, dynamic-island style, into a panel.

Features:

- Issues feed: new good-first-issue and help-wanted issues from big-tech and tooling GitHub orgs, found by an hourly search.
- Custom reminders: one-off or repeating (daily, weekly), fired as critical desktop notifications.
- Tracked PRs and issues: watched for new comments and state changes, polled every 10 minutes.

The widget is QML. The data comes from two Python CLIs in `bin/`, driven by systemd user timers.

## Requirements

- DankMaterialShell >= 1.6 (Quickshell, running on niri or another Wayland compositor)
- `gh`, authenticated (`gh auth login`)
- `python3`
- `notify-send` (libnotify) and a notification daemon
- systemd user session
- GNU `date` (reminder times are parsed with `date -d`)

## Install

```sh
git clone https://github.com/anakafeel/dms-dev-alerts
cd dms-dev-alerts
./install.sh
```

The installer:

- copies `bin/*` to `~/.local/bin`
- copies `plugin/` to `~/.config/DankMaterialShell/plugins/devAlerts`
- copies `config/orgs.txt` to `~/.config/gfi-watch/orgs.txt` only if that file is missing
- copies the units to `~/.config/systemd/user`, runs `systemctl --user daemon-reload`, and enables both timers with `--now`

Then open DMS Settings -> Plugins, enable the plugin, and add `devAlerts` to the bar.

## CLI usage

### gfi-watch

Searches the orgs in the watchlist for new good-first-issue and help-wanted issues. Appends hits to `~/.local/state/gfi-watch/issues.jsonl`, writes a markdown feed to `~/linuxworkspace/gfi-feed.md`, and sends a desktop notification.

```sh
gfi-watch                 # normal run, as the timer does
gfi-watch --hours 48      # widen the look-back window (overlap is deduped)
gfi-watch --min-stars 1000
gfi-watch --all           # ignore the watchlist, search every repo
gfi-watch --quiet         # no notification
gfi-watch --dry-run       # print hits, write nothing
```

`--min-stars` defaults to 500 with the watchlist and 5000 with `--all`.

### devalert

Backend for the widget. State lives in `~/.local/state/devalert/state.json`.

```sh
devalert status                              # JSON consumed by the widget
devalert issue URL new|saved|dismissed       # set an issue's status
devalert remind add TEXT WHEN [--repeat daily|weekly]
devalert remind done ID
devalert track add URL                       # watch an issue or PR
devalert track rm URL
devalert track read URL                      # mark updates as seen
devalert tick [--poll]                       # fire due reminders; --poll also polls tracked items
```

`WHEN` is anything `date -d` accepts, for example `"tomorrow 9am"` or `"2026-11-01 14:30"`.

`tick` runs every minute from `devalert.timer`. It fires due reminders as critical notifications and polls tracked items every 10 minutes.

## Edit the watchlist

Edit `~/.config/gfi-watch/orgs.txt`. One GitHub org per line; lines starting with `#` are comments. The next hourly run picks up the change, or run `gfi-watch --dry-run` to test it. The installer never overwrites this file. The default list is in `config/orgs.txt`.

## File layout

```
bin/gfi-watch            hourly issue search
bin/devalert             widget backend, reminders, tracking
config/orgs.txt          default org watchlist
systemd/gfi-watch.*      hourly service and timer
systemd/devalert.*       per-minute tick service and timer
plugin/                  DMS QML plugin, installed as devAlerts
install.sh               installer
```

## License

MIT. See `LICENSE`.
