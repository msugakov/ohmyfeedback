#!/usr/bin/env bash

set -euo pipefail

sudo="sudo"

export DEBIAN_FRONTEND="noninteractive"
apt_sudo="$sudo --preserve-env=DEBIAN_FRONTEND"
apt_get="$apt_sudo apt-get --yes --no-install-recommends"

color_green="\033[0;32m"
color_off="\033[0m"
if [[ ! -t 1 ]]; then
  color_green=""
  color_off=""
fi

function info() {
  echo -e "$(date --iso-8601=seconds) [INFO] ${color_green}$@${color_off}"
}

if [[ ! -a /var/cache/apt/pkgcache.bin ]] || (( "$(stat --format %Y /var/cache/apt/pkgcache.bin)" + 24*3600 < "$(date +%s)" )); then
  info "It seems that the last update was done more than a day ago, updating"
  $apt_get update
  $apt_get upgrade
else
  info "It seems that the last update is still fresh, skipping update"
fi

info "Installing JRE and other dependencies, if needed"
$apt_get install \
  openjdk-19-jre-headless \
  curl \
  net-tools

if curl --fail -sS -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/ > /dev/null ; then
  info "This seems to be an Oracle Cloud instance, making sure firewall HTTP and HTTPS ports are open"
  # See https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm#set-up-apache-php
  # We could do something better to check for the rule content, not just the rule number, but right now I have no ideas
  # of anything simple and robust.
  if [[ -z "$($sudo iptables -L INPUT 6)" ]]; then
    $sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
    $sudo netfilter-persistent save
  fi
  if [[ -z "$($sudo iptables -L INPUT 7)" ]]; then
    $sudo iptables -I INPUT 7 -m state --state NEW -p tcp --dport 443 -j ACCEPT
    $sudo netfilter-persistent save
  fi
fi


info "Ensuring the service user exists"
# Note that the home directory is unset. We may need it.
cat <<EOF | $sudo tee /usr/lib/sysusers.d/ohmyfeedback.conf
u ohmyfeedback - "OhMyFeedback service user" - -
EOF
$sudo systemd-sysusers

service_user="$(id -u ohmyfeedback)"
service_group="$(id -g ohmyfeedback)"
admin_user="$(id -u)"
admin_group="$(id -g)"

info "Ensuring service directories and permissions are right"
$sudo mkdir -p /ohmyfeedback/{dist,secrets,var,var/tmp}
$sudo chown "$admin_user:$service_group" /ohmyfeedback
$sudo chmod 755 /ohmyfeedback
$sudo chown "$admin_user:$service_group" /ohmyfeedback/dist
$sudo chmod 755 /ohmyfeedback/dist
$sudo chown "$admin_user:$service_group" /ohmyfeedback/secrets
$sudo chmod 750 /ohmyfeedback/secrets
$sudo chown "$service_user:$admin_group" /ohmyfeedback/var
$sudo chmod 755 /ohmyfeedback/dist
$sudo chown "$service_user:$admin_group" /ohmyfeedback/var/tmp
$sudo chmod 755 /ohmyfeedback/var/tmp

info "Ensuring service file exists"
# https://www.freedesktop.org/software/systemd/man/systemd.unit.html
# https://www.freedesktop.org/software/systemd/man/systemd.service.html
# https://www.freedesktop.org/software/systemd/man/systemd.exec.html
cat <<EOF | $sudo tee /etc/systemd/system/ohmyfeedback.service
[Unit]
Description=OhMyFeedback systemd service
StartLimitIntervalSec=0
After=network.target

[Service]
Type=exec
ExecStart=java -jar -Xmx512m -Xms512m -Duser.timezone=UTC /ohmyfeedback/dist/app-all.jar --http-port 80
RestartSec=5
TimeoutStopSec=20
Restart=always
User=$service_user
Group=$service_group
WorkingDirectory=/ohmyfeedback
ProtectProc=invisible
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
TemporaryFileSystem=/ohmyfeedback/var/tmp
PrivateTmp=true
ProtectClock=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
Environment=TEMP=/ohmyfeedback/var/tmp TMP=/ohmyfeedback/var/tmp
AmbientCapabilities=CAP_NET_BIND_SERVICE
# The following should limit listening to only specific ports but for some reason it does not work OOTB.
#SocketBindAllow=tcp:80
#SocketBindAllow=tcp:443
#SocketBindDeny=any

[Install]
WantedBy=multi-user.target
EOF

$sudo systemctl daemon-reload
