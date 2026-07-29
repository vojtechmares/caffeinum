# Caffeinum

A menu bar app for macOS that keeps your Mac awake and sets the daily wake/sleep
schedule. It does nothing else.

Keep-awake is a supervised `caffeinate(8)` process; the schedule is a
`pmset(1) repeat` power event. Caffeinum is a thin, honest front end to both -
the flags it passes are shown in the UI.

## Requirements

macOS 13 or later, and the Swift toolchain from the Xcode Command Line Tools
(`xcode-select --install`). Full Xcode is not required.

## Build and install

```sh
make install     # build, copy into ~/Applications, launch
```

Other targets:

```sh
make build       # build dist/Caffeinum.app
make run         # build and launch from dist/
make universal   # arm64 + x86_64 bundle
make test        # run the test suite
make uninstall   # quit and remove from ~/Applications
make clean
```

The app is ad-hoc signed. That is enough for "launch at login" to work, but it
is not notarised, so the first launch from a downloaded copy would need the
usual right-click → Open. Building locally avoids that.

## Using it

Everything lives in one panel behind the ☕ menu bar icon.

### Keep awake

The master switch starts and stops `caffeinate`. The four checkboxes map
directly onto its assertion flags, and the current command line is shown
underneath:

| Option                     | Flag | Effect                                                       |
| -------------------------- | ---- | ------------------------------------------------------------ |
| Prevent display sleep      | `-d` | The display stays on.                                        |
| Prevent idle sleep         | `-i` | The system does not idle-sleep.                              |
| Prevent disk idle sleep    | `-m` | The disk does not spin down.                                 |
| Prevent sleep on AC power  | `-s` | The system does not sleep at all - only honoured on AC power. |

With every box unchecked Caffeinum falls back to `-i`, which is what bare
`caffeinate` does anyway.

**For** sets how long the session lasts: indefinitely, a preset length, or until
a time you pick. While a timed session runs, the remaining time appears next to
the menu bar icon.

The `caffeinate` process is started with `-w <Caffeinum's pid>`, so if Caffeinum
is force quit or crashes, the assertions are released rather than leaving the
Mac awake indefinitely.

### Daily schedule

Wake and sleep times, and the days they apply on, become a single
`pmset repeat` power event:

```
sudo pmset repeat wakeorpoweron MTWRF 08:00:00 sleep MTWRF 23:30:00
```

Edits are staged until you press **Apply schedule**, which puts up the standard
macOS authentication dialog - macOS only lets root set power events, and
Caffeinum asks for that permission at the moment it needs it rather than
installing a privileged helper that stays on your Mac.

Two things worth knowing, both from `pmset` rather than Caffeinum:

- macOS supports exactly one repeating wake event and one repeating sleep event
  system-wide, so applying a schedule replaces whatever was there, including one
  set in System Settings → Battery → Schedule.
- Wake and sleep share one day selection, because that is how `pmset repeat`
  models it.

The schedule lives in the system, not in Caffeinum. It keeps working when the
app is not running, and survives a reboot.

### System power events

The disclosure at the bottom of the panel lists what `pmset -g sched` reports -
both the repeating schedule and one-time events queued by macOS or other apps -
with buttons to clear either group.

### Behaviour

- **Launch at login** registers the app with `SMAppService`. It needs Caffeinum
  to be running from an installed bundle; the toggle is disabled otherwise.
- **Restore keep awake on launch** turns the session back on at startup if it
  was on when you last quit.
- **Global shortcut** toggles keep-awake from anywhere. Click the shortcut to
  record a new one; ⎋ cancels. It is registered through Carbon's
  `RegisterEventHotKey`, so it needs no Accessibility permission.

## Layout

```
Sources/Caffeinum/
  CaffeinumApp.swift          MenuBarExtra scene and app delegate
  AppCoordinator.swift        wires preferences to the pieces that act on them
  Model/                      Preferences, Weekday, TimeOfDay, AwakeDuration
  System/                     caffeinate, pmset, login item, hot key, shell
  Views/                      the menu panel
Tests/CaffeinumTests/         unit tests plus offscreen renders of the panel
scripts/build-app.sh          SwiftPM build, bundle assembly, icon, ad-hoc sign
scripts/make-icon.swift       renders AppIcon.icns
scripts/test.sh               swift test, pointed at the toolchain's Testing.framework
```

`make test` writes PNG renders of the menu panel; set `CAFFEINUM_RENDER_DIR` to
choose where they land.

## License

MIT - see [LICENSE](LICENSE).
