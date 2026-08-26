# Troubleshooting

## No menu bar icon

Almost always the notch. macOS parks surplus status items in the dead zone
behind it and gives no indication — the item exists, has a window, and is
simply not drawable.

The app seeds a preferred position on first run to land clear of it. If it is
still missing, ⌘-drag your menu bar icons to rearrange; whatever you choose is
what persists from then on.

To confirm it is running at all:

```bash
pgrep -fl GAMSessions
```

If that returns a pid and you see nothing, it is a placement problem, not a
launch problem.

## `gam: command not found` in the Terminal it opens

GAM is not in one of the searched directories. The app probes
`~/bin/gamadv-xtd3`, `~/bin/gam7`, `~/bin/gam`, `/usr/local/bin`, and
`/opt/homebrew/bin`, and prepends the first one holding an executable `gam`.

Point one of them at your install:

```bash
mkdir -p ~/bin && ln -s /path/to/your/gam ~/bin/gam
```

A login shell's own `PATH` is not used, deliberately — `do script` starts a
non-interactive shell whose environment differs from your Terminal's, and
relying on it made this fail inconsistently.

## Two menu bar icons

Fixed — the app exits at launch if another instance is already running. If you
see it on an older build, rebuild:

```bash
./build.sh
```

## Service account key blocked by org policy

The failure looks like this. The project step reports:

```
Upload Failed: Constraint constraints/iam.disableServiceAccountKeyUpload violated
```

GAM generates the keypair locally and uploads the public half. Orgs that set
that constraint reject the upload, and GAM writes `oauth2service.json` with an
empty `private_key`. Every later service-account command then fails before it
can do anything:

```
Unable to load PEM file ... MalformedFraming
```

**`gam create sakey` cannot fix this.** It authenticates *as* the service
account, so it needs a working key to mint one. Making the file merely
*parseable* (a syntactically valid throwaway PEM) gets past the load check and
then fails at the next step with `401 authError`, because Google has no
registered public key matching it. There is no local repair.

Two real ways out:

**1. Let Google mint the key.** Cloud Console → IAM & Admin → Service Accounts
→ the service account → Keys → Add key → Create new key → JSON. Save the
download over `oauth2service.json` in that company's config directory. No
editing — the Console's JSON has exactly the fields GAM expects. Nothing is
uploaded, so `disableServiceAccountKeyUpload` does not apply.

**2. Scope the constraint off that project.** Cloud Console → IAM & Admin →
Organization policies → `iam.disableServiceAccountKeyUpload` → Manage policy →
add a rule for the project with enforcement off. Needs an org admin, and can be
scoped to the one project rather than the whole org.

If (1) is also refused, the blocker is the separate
`iam.disableServiceAccountKeyCreation` constraint and only (2) will do.

**Or do without.** Plain OAuth covers directory, group, OU and reporting
commands. You lose only `gam user <email> ...` against Drive, Gmail and
Calendar contents. For a tenant you administer but do not extract data from,
this costs nothing.

## `client_secrets.json` vs `oauth2service.json`

Easy to conflate, since both are JSON downloads from the same Cloud project.

| | Starts with | Contains | From |
|---|---|---|---|
| `client_secrets.json` | `{"installed": {…}}` | `client_id`, `client_secret`, no private key | APIs & Services → Credentials |
| `oauth2service.json` | `{"type": "service_account", …}` | `private_key`, `client_email` ending `.iam.gserviceaccount.com` | IAM & Admin → Service Accounts → *the SA* → Keys |

If a service-account command fails, check which file you actually installed:

```bash
python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('type','oauth client'))" \
  ~/.gam-companies/acme/oauth2service.json
```

## `client_secrets.json already exists. Please delete or rename it`

`gam use project` refuses to overwrite one. Move it aside rather than deleting
— if the new project step fails you will want the old one back:

```bash
cd ~/.gam-companies/acme && mv client_secrets.json client_secrets.json.old
```

## Removing an app's access

Three separate layers. Removing one does not do the others.

**Revoke one account's grant** — undoes `gam oauth create`:

```bash
export GAMCFGDIR="$HOME/.gam-companies/acme"; gam oauth delete
```

Revokes the token with Google and deletes the local `oauth2.txt`. By hand:
[myaccount.google.com/connections](https://myaccount.google.com/connections).

**Block it domain-wide** — admin console → Security → Access and data control →
API controls → Manage Third-Party App Access. Note this page has no delete:
it stores a *setting* per app, so the only action is Change access → Blocked.
The app and its Cloud project survive.

Domain-wide delegation entries are removed separately, in the same section
under Domain-wide delegation.

**Delete the underlying app** — Cloud Console → APIs & Services → Credentials
→ delete the OAuth client, or IAM & Admin → Settings → Shut down to remove the
whole project. Shutdown is recoverable for 30 days; after that the client ID
and any service accounts in it are gone.

The numeric prefix of an OAuth client ID is its project number, which is enough
to find an orphan:

```
https://console.cloud.google.com/apis/credentials?project=<prefix>
```

Before shutting a project down, check nothing on disk still uses it:

```bash
grep -rl "<project-id>" ~/.gam-companies/
```
