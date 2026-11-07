#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX_NAME="ledger"
BUILD_USER="skip"
PLAYER_USER="mira"
ARCHIVE_GROUP="archive-ops"
# Build-only placeholder. Replace before freezing the VM and record privately.
PLAYER_PASSWORD="AutumnReports!2026"
WEB_ADMIN_PASSWORD="sunshine"
ROOT_PASSWORD='G7!vQ2@xN9#kR4$zT8&mP6_Wc'
USER_FLAG="4d186321c1a7f0f354b297e8914ab240"
ROOT_FLAG="8f14e45fceea167a5a36dedd4bea2543"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -o APT::Get::Always-Include-Phased-Updates=true -y full-upgrade
apt-get install -y curl iputils-ping locales nginx openssh-server python3 python3-venv sqlite3 sudo ufw

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

hostnamectl set-hostname "${BOX_NAME}"
if ! grep -qE "^127\.0\.1\.1[[:space:]]+${BOX_NAME}([[:space:]]|$)" /etc/hosts; then
    printf '127.0.1.1 %s\n' "${BOX_NAME}" >> /etc/hosts
fi

getent group "${PLAYER_USER}" >/dev/null || groupadd "${PLAYER_USER}"
getent group "${ARCHIVE_GROUP}" >/dev/null || groupadd --system "${ARCHIVE_GROUP}"
id "${PLAYER_USER}" >/dev/null 2>&1 || useradd -m -g "${PLAYER_USER}" -s /bin/bash "${PLAYER_USER}"
usermod -aG "${ARCHIVE_GROUP}" "${PLAYER_USER}"
printf '%s:%s\n' "${PLAYER_USER}" "${PLAYER_PASSWORD}" | chpasswd
chage -M -1 -E -1 "${PLAYER_USER}"
printf 'root:%s\n' "${ROOT_PASSWORD}" | chpasswd
chage -M -1 -E -1 root

id ledger >/dev/null 2>&1 || useradd --system --home /opt/ledger --shell /usr/sbin/nologin ledger
install -d -m 0755 -o ledger -g ledger /opt/ledger/app /opt/ledger/data /opt/ledger/reports
install -d -m 0755 -o ledger -g ledger /opt/ledger/app/templates
install -d -m 0755 -o ledger -g ledger /opt/ledger/app/static
cp "${PROJECT_DIR}/app/app.py" /opt/ledger/app/app.py
cp "${PROJECT_DIR}/app/init_db.py" /opt/ledger/app/init_db.py
cp "${PROJECT_DIR}"/app/templates/*.html /opt/ledger/app/templates/
cp "${PROJECT_DIR}"/app/static/*.css /opt/ledger/app/static/
cp "${PROJECT_DIR}"/app/static/*.js /opt/ledger/app/static/
cp "${PROJECT_DIR}/app/requirements.txt" /opt/ledger/app/requirements.txt
chown -R ledger:ledger /opt/ledger/app

python3 -m venv /opt/ledger/venv
/opt/ledger/venv/bin/pip install --no-cache-dir -r /opt/ledger/app/requirements.txt
chown -R ledger:ledger /opt/ledger/venv

/opt/ledger/venv/bin/python /opt/ledger/app/init_db.py /opt/ledger/data/ledger.db "${WEB_ADMIN_PASSWORD}"
chown ledger:ledger /opt/ledger/data/ledger.db
chmod 0640 /opt/ledger/data/ledger.db

cat > "/opt/ledger/reports/q3-summary.txt" <<'EOF'
Q3 2026 close — controller summary
==================================

Owner  : Mira Cole (reporting analyst)
Period : Q3 2026 · Northbridge Accounting
Status : Approved by reports-admin on 12 October 2026

Scope of this snapshot
----------------------
The nightly maintenance job promotes reviewed reports from the analyst
workspace into the restricted night-operations queue. That queue, rather than
this working folder, is repacked into the offsite snapshot.

Highlights
----------
- Quarterly reconciliation completed. No exceptions recorded.
- Legacy Northwind archive reconciliation moved to the night-operations
  queue; three unmatched records are still under review.
- FX rates validated against treasury reference data on 2 October.
EOF
chown -R "${PLAYER_USER}:${PLAYER_USER}" /opt/ledger/reports
chmod 0775 /opt/ledger/reports

install -d -m 0770 -o root -g "${ARCHIVE_GROUP}" /var/spool/ledger/nightly
cp /opt/ledger/reports/q3-summary.txt /var/spool/ledger/nightly/approved-q3-summary.txt
chown root:"${ARCHIVE_GROUP}" /var/spool/ledger/nightly/approved-q3-summary.txt
chmod 0660 /var/spool/ledger/nightly/approved-q3-summary.txt

install -d -m 0755 -o root -g root /usr/local/share/ledger-seed
install -m 0644 -o root -g root \
    /opt/ledger/reports/q3-summary.txt /usr/local/share/ledger-seed/q3-summary.txt

install -d -m 0755 -o root -g root /etc/ledger
cat > /etc/ledger/archive.conf <<'EOF'
# Night Operations archive profile. Analysts in archive-ops may inspect and
# populate the queue; only root may alter the profile.
QUEUE_DIR=/var/spool/ledger/nightly
ARCHIVE_NAME=reports.tgz
EOF
chown root:"${ARCHIVE_GROUP}" /etc/ledger/archive.conf
chmod 0640 /etc/ledger/archive.conf

install -m 0755 -o root -g root "${PROJECT_DIR}/provision/ledger-backup" /usr/local/sbin/ledger-backup
cat > /etc/sudoers.d/ledger-backup <<EOF
Defaults:${PLAYER_USER} env_keep += "TERMINFO"
${PLAYER_USER} ALL=(root) NOPASSWD: /usr/local/sbin/ledger-backup
EOF
chmod 0440 /etc/sudoers.d/ledger-backup
visudo -cf /etc/sudoers.d/ledger-backup

install -d -m 0755 -o root -g root /etc/ledger
cat > /etc/ledger/ledger.env <<EOF
FLASK_SECRET_KEY=ledger-session-key-change-before-freeze
MIRA_IMPORT_USER=${PLAYER_USER}
MIRA_IMPORT_PASSWORD=${PLAYER_PASSWORD}
EOF
chown root:ledger /etc/ledger/ledger.env
chmod 0640 /etc/ledger/ledger.env

install -m 0644 "${PROJECT_DIR}/provision/ledger.service" /etc/systemd/system/ledger.service
install -m 0755 -o root -g root "${PROJECT_DIR}/provision/remove-build-user" /usr/local/sbin/ledger-remove-build-user
install -m 0644 "${PROJECT_DIR}/provision/ledger-remove-build-user.service" /etc/systemd/system/ledger-remove-build-user.service
install -m 0644 "${PROJECT_DIR}/provision/nginx-ledger.conf" /etc/nginx/sites-available/ledger
ln -sfn /etc/nginx/sites-available/ledger /etc/nginx/sites-enabled/ledger
rm -f /etc/nginx/sites-enabled/default
nginx -t

printf '%s\n' "${USER_FLAG}" > "/home/${PLAYER_USER}/user.txt"
chown "root:${PLAYER_USER}" "/home/${PLAYER_USER}/user.txt"
chmod 0640 "/home/${PLAYER_USER}/user.txt"
printf '%s\n' "${ROOT_FLAG}" > /root/root.txt
chown root:root /root/root.txt
chmod 0640 /root/root.txt

for history in \
    "/home/${PLAYER_USER}/.bash_history" \
    "/home/${PLAYER_USER}/.mysql_history" \
    "/home/${PLAYER_USER}/.python_history" \
    "/home/${PLAYER_USER}/.viminfo" \
    /root/.bash_history \
    /root/.mysql_history \
    /root/.python_history \
    /root/.viminfo; do
    rm -f "${history}"
    ln -s /dev/null "${history}"
    chown -h root:root "${history}"
done

PRIMARY_IF="$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -v '^lo$' | head -n 1)"
if [[ -z ${PRIMARY_IF} ]]; then
    echo "No non-loopback network interface found." >&2
    exit 1
fi
install -d -m 0755 /etc/systemd/network
cat > /etc/systemd/network/10-ledger-dhcp.network <<EOF
[Match]
Name=${PRIMARY_IF}

[Network]
DHCP=ipv4
IPv6AcceptRA=no
LinkLocalAddressing=no
EOF
chmod 0644 /etc/systemd/network/10-ledger-dhcp.network
rm -f /etc/netplan/*.yaml
apt-get purge -y netplan.io netplan-generator || true
systemctl enable systemd-networkd systemd-resolved

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'OpenSSH'
ufw allow 80/tcp comment 'Ledger web'
ufw --force enable

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
cat > /etc/ssh/sshd_config.d/90-ledger.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
X11Forwarding no
AllowUsers skip mira
MaxAuthTries 4
EOF
sshd -t
systemctl daemon-reload
if id "${BUILD_USER}" >/dev/null 2>&1; then
    systemctl enable ledger-remove-build-user.service
else
    echo "Warning: build user '${BUILD_USER}' does not exist; removal service not enabled." >&2
fi
systemctl enable ledger nginx ssh
systemctl restart ledger nginx ssh

# Final one-shot cleanup. No periodic scrub is shipped in the challenge image:
# player state must remain stable during a solve.
bash "${PROJECT_DIR}/provision/ledger-scrub"

echo "Provisioning complete. Reboot, then run the acceptance checklist."

