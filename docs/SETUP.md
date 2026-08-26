# Adding a company

Each company is a GAM config directory under `~/.gam-companies/`. It holds that
tenant's `gam.cfg`, `client_secrets.json`, `oauth2.txt`, `oauth2service.json`
and `gamcache/`. Nothing else in the system knows about companies — the menu is
just a listing of that directory.

## Reusing a config you already have

If you already have a working GAM setup for a tenant, symlink it. No re-auth,
no second Cloud project:

```bash
ln -s ~/gam-acme ~/.gam-companies/acme
```

It shows up in the menu on the next click. The app follows symlinks when
listing, so the target can live anywhere.

## Setting one up from scratch

**Add Company…** (⌘N) creates the directory and opens a Terminal already
scoped to it — `GAMCFGDIR` is exported, so every `gam` command in that window
affects only this company. Run, in order:

```bash
gam create project      # new Google Cloud project, or:
gam use project <id>    # reuse an existing one
gam oauth create        # authorize a super-admin of this Workspace
```

The app prints these rather than running them. They create real Google Cloud
resources and need an interactive browser sign-in as an admin of that specific
tenant, which is not something a menu click should do on your behalf.

`gam create project` makes a Cloud project, enables the APIs, creates an OAuth
client and a service account. `gam use project <id>` does the same against a
project that already exists — use it when a tenant already has a GAM project
you'd otherwise duplicate.

`gam oauth create` opens a browser, asks which scopes to authorize, and writes
`oauth2.txt`. Sign in as a super-admin **of that tenant**, not of your own
domain. This is the step that determines which Workspace the config talks to.

## Verifying

```bash
export PATH="$HOME/bin/gamadv-xtd3:$PATH"
export GAMCFGDIR="$HOME/.gam-companies/acme"

gam info domain                                  # OAuth token + right tenant?
gam user someone@acme.com check serviceaccount   # service account + delegation?
```

`gam info domain` returns the customer ID and primary domain. Check the domain
is the one you expect — an `oauth2.txt` authorized against the wrong tenant is
the one mistake this tool exists to prevent, and it is invisible otherwise.

`check serviceaccount` impersonates a user and reports pass/fail per scope. It
tests three things at once: the private key, the domain-wide delegation entry
in that tenant's admin console, and the scope list. Failures tell you which.

## Service accounts and domain-wide delegation

Two credentials, two jobs:

| Credential | File | Authenticates | Needed for |
|---|---|---|---|
| OAuth client + token | `client_secrets.json`, `oauth2.txt` | you, as an admin | directory, groups, OUs, reporting — most commands |
| Service account key | `oauth2service.json` | the service account, impersonating a user | `gam user <email> ...` against Drive, Gmail, Calendar contents |

You can run a company on OAuth alone. The service account is only required to
reach into individual users' data. If the key is blocked by org policy — see
[TROUBLESHOOTING](TROUBLESHOOTING.md#service-account-key-blocked-by-org-policy)
— the company still works for everything else.

The service account also needs its client ID registered in the tenant's admin
console under Security → Access and data control → API controls → Domain-wide
delegation, with the scopes GAM asks for. `check serviceaccount` prints exactly
what is missing.

## Deleting a company

**Delete Company ▸** moves the directory to the Trash after confirming. It is
never `rm`-ed: that directory is the only copy of the OAuth token, and putting
it back from the Trash is the difference between an inconvenience and a re-auth
against a tenant you may not personally administer.

Removing the config does not revoke anything Google-side. To actually revoke,
see [TROUBLESHOOTING](TROUBLESHOOTING.md#removing-an-apps-access).
