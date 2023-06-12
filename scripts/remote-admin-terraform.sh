#!/usr/bin/env bash

set -euo pipefail

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

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

if [[ ! -d /ohmyfeedback \
  || ! -a /var/cache/apt/pkgcache.bin ]] \
  || (( "$(stat --format %Y /var/cache/apt/pkgcache.bin)" + 24*3600 < "$(date +%s)" )); then
  info "It seems that the last update was done more than a day ago, updating"
  $apt_get update
  $apt_get upgrade
else
  info "It seems that the last update is still fresh, skipping update"
fi

info "Installing rbenv&ruby-build and other dependencies, if needed"
$apt_get install \
  autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev \
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

info "Installing rbenv for the admin user"
if [[ ! -d ~/.rbenv ]]; then \
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
fi
git -C ~/.rbenv checkout --quiet 38e1fbb08e9d75d708a1ffb75fb9bbe179832ac8
if [[ ! -d ~/.rbenv/plugins/ruby-build ]]; then \
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi
git -C ~/.rbenv/plugins/ruby-build checkout --quiet 4effe8661b407c939cadb75280aafce6ba449057
ruby_version="$(cat "${script_dir}"/.ruby-version)"
info "Installing ruby $ruby_version if needed"
~/.rbenv/bin/rbenv install --verbose --skip-existing "$ruby_version"

info "Ensuring the service user exists"
# Note that the home directory is unset. We may need it.
cat <<EOF | $sudo tee /usr/lib/sysusers.d/ohmyfeedback.conf
#Type  Name          ID  GECOS                       Home directory  Shell
u      ohmyfeedback  -  "OhMyFeedback service user"  -               -
EOF
$sudo systemd-sysusers

service_user="$(id -u ohmyfeedback)"
service_group="$(id -g ohmyfeedback)"
admin_user="$(id -u)"
admin_group="$(id -g)"

info "Ensuring service directories and permissions are right"
$sudo mkdir -p /ohmyfeedback/{dist,secrets,var,var/tmp,ruby-dists,certbot,certbot/for-java}
$sudo chown "$admin_user:$service_group" /ohmyfeedback
$sudo chmod 755 /ohmyfeedback
$sudo chown "$admin_user:$service_group" /ohmyfeedback/dist
$sudo chmod 755 /ohmyfeedback/dist
$sudo chown "$admin_user:$service_group" /ohmyfeedback/secrets
$sudo chmod 750 /ohmyfeedback/secrets
$sudo chown "$service_user:$admin_group" /ohmyfeedback/var
$sudo chmod 755 /ohmyfeedback/dist
$sudo chown "$admin_user:$admin_group" /ohmyfeedback/var/tmp
$sudo chmod 755 /ohmyfeedback/var/tmp
$sudo chown "$admin_user:$admin_group" /ohmyfeedback/ruby-dists
$sudo chmod 755 /ohmyfeedback/ruby-dists
$sudo chown "root:$admin_group" /ohmyfeedback/certbot
$sudo chmod 750 /ohmyfeedback/certbot
$sudo chown "root:$admin_group" /ohmyfeedback/certbot/for-java
$sudo chmod 770 /ohmyfeedback/certbot/for-java

info "Copying ruby for service use"
rsync --archive --safe-links --del --delete --force --info=stats1 \
  "$HOME/.rbenv/versions/$ruby_version/" "/ohmyfeedback/ruby-dists/$ruby_version/"
rm --verbose --force /ohmyfeedback/ruby-new
ln --verbose --symbolic "/ohmyfeedback/ruby-dists/$ruby_version" /ohmyfeedback/ruby-new
mv --verbose --no-target-directory /ohmyfeedback/ruby-new /ohmyfeedback/ruby

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
ExecStart=java -jar -Xmx512m -Xms512m -Duser.timezone=UTC \
  /ohmyfeedback/dist/app-all.jar \
  --http-port 80 \
  --https-port 443 \
  --cert-keystore secrets/keystore.jks
RestartSec=5
TimeoutStopSec=20
Restart=always
User=$service_user
Group=$service_group
WorkingDirectory=/ohmyfeedback
ProtectProc=invisible
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/ohmyfeedback/var
ProtectHome=true
TemporaryFileSystem=/ohmyfeedback/var/tmp:noatime,nodev,noexec,nosuid,mode=0777
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
