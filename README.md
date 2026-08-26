# GAM Sessions

A macOS menu-bar app for running [GAM](https://github.com/GAM-team/GAM) against
several Google Workspace tenants without them treading on each other.

Pick a company from the menu bar, get a Terminal shell whose `GAMCFGDIR` points
at that company's own config — its own OAuth token, its own service account, its
own cache. No re-authorizing when you switch, and no way to accidentally run a
command against the wrong tenant.

Built for managing a portfolio of companies. Anything with more than one
Workspace tenant works the same way.

## Requirements

- macOS 13 or later
- Xcode command line tools (`xcode-select --install`), for `swiftc`
- GAM already installed — [GAM7](https://github.com/GAM-team/GAM) or
  [GAMADV-XTD3](https://github.com/taers232c/GAMADV-XTD3). The app looks in
  `~/bin/gamadv-xtd3`, `~/bin/gam7`, `~/bin/gam`, `/usr/local/bin` and
  `/opt/homebrew/bin`.

## Install

```bash
git clone https://github.com/TinyLtd/gam-sessions.git
cd gam-sessions
./install.sh
```

Builds the app, copies it to `/Applications`, and registers a LaunchAgent so it
starts at login. A **G** appears in your menu bar.

```bash
./install.sh uninstall
```

Removes the app and the login item. Your configs in `~/.gam-companies` are left
alone.

## Use

Click the **G**:

- **A company name** — opens a Terminal scoped to that company and runs
  `gam info domain`, so the window tells you which tenant you are in.
- **Add Company…** (⌘N) — creates its config directory and opens a Terminal
  with the setup commands.
- **Delete Company ▸** — moves a company's config to the Trash, after
  confirming.

Each company is just a directory under `~/.gam-companies/`. Nothing is hidden in
a database — inspect it, back it up, or hand-edit it. Already have a working GAM
config? Symlink it instead of setting it up again:

```bash
ln -s ~/gam-acme ~/.gam-companies/acme
```

## Docs

- [Adding a company](docs/SETUP.md) — the GAM setup sequence, verifying a
  connection, service accounts and domain-wide delegation
- [Troubleshooting](docs/TROUBLESHOOTING.md) — missing menu bar icon, `gam` not
  on `PATH`, service-account keys blocked by org policy, revoking app access
- [How it works](docs/ARCHITECTURE.md) — the design, and the decisions behind it

## Development

```bash
./build.sh                                                  # build only
./GAMSessions.app/Contents/MacOS/GAMSessions --selftest     # name-guard checks
./install-startup.sh                                        # login item for the local build
```

Everything is in [main.swift](main.swift) — a couple of hundred lines, AppKit
only, no dependencies. See [How it works](docs/ARCHITECTURE.md) before editing
the Terminal command: its quoting is three levels deep and an apostrophe in the
wrong place breaks it silently.

Regenerating the icons after changing `icon-source.jpg`:

```bash
swiftc -O mkicon.swift -o /tmp/mkicon
/tmp/mkicon icon-source.jpg icon.png            # 36px menu bar template
/tmp/mkicon icon-source.jpg /tmp/big.png 1024   # app icon master
```

Then `sips` and `iconutil` to build `AppIcon.icns` from the 1024px master.
