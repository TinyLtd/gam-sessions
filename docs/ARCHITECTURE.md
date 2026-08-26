# How it works

One Swift file, AppKit only, no dependencies. ~220 lines.

## The whole idea

GAM reads its configuration from the directory named by `GAMCFGDIR`. That one
environment variable is the isolation boundary: token, service account, cache
and settings all live inside it. So "switching company" is nothing more than
exporting a different path.

The app is a menu of directory names. Clicking one runs:

```bash
export PATH='<gam dir>':$PATH
export GAMCFGDIR='<company dir>'
cd '<company dir>'
gam info domain | head -3
```

in a new Terminal window, via AppleScript `do script`. There is no daemon, no
state, no config file of its own. Delete the app and your GAM setups are
untouched; delete `~/.gam-companies` and the menu is empty.

`gam info domain` runs on open so the window announces which tenant it is
talking to before you type anything.

## Files

| File | Role |
|---|---|
| `main.swift` | the app |
| `build.sh` | compile + bundle + ad-hoc sign |
| `install.sh` | build, copy to `/Applications`, register login item |
| `install-startup.sh` | the login item alone (`GAM_APP` to point it elsewhere) |
| `mkicon.swift` | one-off JPEG → template PNG converter for the icons |

## Decisions worth knowing

**Menu rebuilt on every open.** `menuNeedsUpdate` reads the directory each
time, so companies added or removed outside the app appear without a restart.
The directory is the source of truth; there is no cache to invalidate.

**Names are validated when listing, not only when creating.** They are
interpolated into a shell command inside an AppleScript string literal, so a
name carrying a quote would break out. `isValidName` restricts to
`[A-Za-z0-9._-]` and rejects `.` and `..` — the charset alone accepts `..`,
which resolves to the parent of the config directory. Validating at the listing
choke point means a directory created by hand is covered too, not just one
created through the dialog. `--selftest` exercises this.

**Quoting is three levels deep** — Swift string → AppleScript literal → shell.
The setup text uses "will not" and "cannot" because an apostrophe would
terminate the shell's single-quoted string, and no double quotes because those
would terminate the AppleScript literal. Newlines are illegal in an AppleScript
literal at all, hence one long `;`-joined line. When editing that block, verify
by reconstructing and running it rather than by reading it.

**`PATH` is set explicitly.** `do script` runs a shell whose environment is not
your interactive Terminal's, so GAM is frequently absent from it. The app probes
known install locations and prepends the one it finds. `PATH='x':$PATH` needs no
quotes around `$PATH` — assignment context does not word-split — which also
keeps double quotes out of the AppleScript literal.

**Deletion goes to the Trash.** `FileManager.trashItem`, never `unlink`. That
directory is the only copy of an OAuth token for a tenant you may not
personally administer.

**Single instance, checked at runtime.** `NSRunningApplication` filtered by
bundle identifier, in `applicationDidFinishLaunching`. Not the
`LSMultipleInstancesProhibited` Info.plist key, which looks tidier but is only
honoured for LaunchServices bundle launches — the LaunchAgent execs the binary
directly and would slip past it.

**Status item position is seeded once.** macOS parks surplus status items in the
notch dead zone with no API to detect it and no error. `NSScreen`'s
`auxiliaryTopLeftArea` and `auxiliaryTopRightArea` bracket the notch, so you can
measure where it is, but you cannot ask whether your item landed behind it. The
app writes a `NSStatusItem Preferred Position` default on first run only — after
that the user's ⌘-drag is what persists.

**Login item is a LaunchAgent, not a System Events login item.** `make new
login item` needs Automation approval and fails with `-1719` when it is not
granted. launchd needs no permission grant. `RunAtLoad` without `KeepAlive`, so
Quit actually quits instead of being relaunched a second later.

**Setup commands are printed, not run.** `gam create project` and
`gam oauth create` create real Cloud resources and need an interactive sign-in
as an admin of the target tenant. A menu click should not do that.
