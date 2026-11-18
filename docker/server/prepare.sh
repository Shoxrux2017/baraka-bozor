#!/usr/bin/env bash
# Prepares a fresh Ubuntu 24.04 server for docker/deploy.sh (DL-141 (8)). Run
# once, as root, from a copy of this file (the clone does not exist yet):
#
#   sudo bash prepare.sh
#
# Safe to run again: each step is skipped when it is already done. It keeps the
# image's own user (ubuntu on Lightsail), adds a `deploy` user for the
# deployments, closes password logins and opens only ports 22, 80 and 443. A
# re-run copies ubuntu's authorized_keys over deploy's again, so a key added to
# deploy alone is lost.
set -euo pipefail
export MSYS_NO_PATHCONV=1

REPO_URL="https://github.com/Shoxrux2017/baraka-bozor.git"
BB_HOME=/opt/barakabozor
DEPLOY_USER=deploy
SWAP_FILE=/swapfile

say() { printf 'prepare: %s\n' "$*"; }
die() { printf 'prepare: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root: sudo bash prepare.sh"
# shellcheck disable=SC1091
. /etc/os-release
{ [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ]; } || die "this script is for Ubuntu 24.04, not ${PRETTY_NAME:-this system}"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# write_file PATH MODE: stdin becomes the file when it differs; returns 0 when
# the file changed.
write_file() {
  local path="$1" mode="$2" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$path" ] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi
  install -m "$mode" -o root -g root "$tmp" "$path"
  rm -f "$tmp"
  return 0
}

# 1. Packages.
say "packages"
# A changed config file keeps the local version instead of asking.
APT_KEEP=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
apt-get update -qq
apt-get upgrade -y -qq "${APT_KEEP[@]}"
apt-get install -y -qq "${APT_KEEP[@]}" ca-certificates curl git jq ufw unattended-upgrades

# 2. Swap, for the image builds on a 4 GB machine.
if ! swapon --show=NAME --noheadings | grep -qx "$SWAP_FILE"; then
  if [ ! -f "$SWAP_FILE" ]; then
    say "creating 2 GB of swap"
    fallocate -l 2G "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" > /dev/null
  fi
  swapon "$SWAP_FILE"
fi
if ! grep -qE "^$SWAP_FILE[[:space:]]" /etc/fstab; then
  printf '%s none swap sw 0 0\n' "$SWAP_FILE" >> /etc/fstab
fi
if write_file /etc/sysctl.d/90-barakabozor.conf 644 <<< 'vm.swappiness=10'; then
  sysctl --system > /dev/null
fi

# 3. Docker Engine and the Compose plugin, from Docker's own repository.
install -m 0755 -d /etc/apt/keyrings
if [ ! -s /etc/apt/keyrings/docker.asc ]; then
  say "Docker's signing key"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi
docker_list="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable"
if write_file /etc/apt/sources.list.d/docker.list 644 <<< "$docker_list"; then
  apt-get update -qq
fi
apt-get install -y -qq "${APT_KEEP[@]}" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
install -m 0755 -d /etc/docker
if write_file /etc/docker/daemon.json 644 <<< '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"},"userland-proxy":false}'; then
  say "Docker's daemon settings changed; restarting Docker"
  systemctl restart docker
fi
systemctl enable --now docker > /dev/null 2>&1

# 4. The deploy user, with the key the instance was created with.
if ! id "$DEPLOY_USER" > /dev/null 2>&1; then
  say "creating the user $DEPLOY_USER"
  adduser --disabled-password --gecos "" "$DEPLOY_USER" > /dev/null
fi
usermod -aG docker "$DEPLOY_USER"
source_keys=/home/ubuntu/.ssh/authorized_keys
[ -s "$source_keys" ] || die "$source_keys is missing or empty; the instance needs the SSH key chosen at its creation"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$source_keys" "/home/$DEPLOY_USER/.ssh/authorized_keys"

# 5. SSH: keys only, no root. The 00- name is read first, so it wins over the
# image's own drop-ins.
if write_file /etc/ssh/sshd_config.d/00-barakabozor.conf 644 << 'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
CONF
then
  if ! sshd -t; then
    rm -f /etc/ssh/sshd_config.d/00-barakabozor.conf
    die "sshd rejects the new SSH settings; they were removed and SSH is unchanged"
  fi
  systemctl reload ssh
  say "SSH reloaded: keys only"
fi

# 6. Firewall. Docker publishes ports around ufw, so the provider's firewall
# stays the real guard for 80 and 443; ufw covers everything else.
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow OpenSSH > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw --force enable > /dev/null

# 7. Security upgrades, rebooting at 00:30 UTC (05:30 in Tashkent) when needed.
write_file /etc/apt/apt.conf.d/20auto-upgrades 644 << 'CONF' || true
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
write_file /etc/apt/apt.conf.d/52barakabozor 644 << 'CONF' || true
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "00:30";
CONF

# 8. The layout and the clone. The repository is public: no credential.
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$BB_HOME"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$BB_HOME/state" "$BB_HOME/dumps"
# Caddy's container reads these two as another user.
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$BB_HOME/maintenance" "$BB_HOME/panel" "$BB_HOME/panel/releases"
# The backup container runs as uid 10001.
install -d -m 700 -o 10001 -g 10001 "$BB_HOME/backup-repo"
if [ ! -d "$BB_HOME/repo/.git" ]; then
  say "cloning $REPO_URL"
  sudo -u "$DEPLOY_USER" git clone --quiet "$REPO_URL" "$BB_HOME/repo"
fi

# 9. The summary.
say "summary"
docker --version
docker compose version
ufw status | sed 's/^/prepare:   /'
swapon --show | sed 's/^/prepare:   /'
df -h / | sed 's/^/prepare:   /'
if [ -e /var/run/reboot-required ]; then
  say "a reboot is required: sudo reboot"
else
  say "no reboot is required"
fi
say "the group docker of $DEPLOY_USER takes effect at its next login"
