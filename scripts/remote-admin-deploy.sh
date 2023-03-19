#!/usr/bin/env bash

set -euo pipefail

sudo=sudo

color_green="\033[0;32m"
color_red="\033[0;31m"
color_off="\033[0m"
if [[ ! -t 1 ]]; then
  color_green=""
  color_red=""
  color_off=""
fi

function info() {
  echo -e "$(date --iso-8601=seconds) [INFO] ${color_green}$@${color_off}"
}
function error() {
  echo -e "$(date --iso-8601=seconds) [ERROR] ${color_red}$@${color_off}"
}

info "Stopping old service"
$sudo systemctl stop ohmyfeedback.service

info "Copying over new jar"
cp -v /ohmyfeedback/deploy/app-all.jar /ohmyfeedback/dist/app-all.jar

info "Starting new service"
$sudo systemctl start ohmyfeedback.service

info "Enabling service start on reboot"
$sudo systemctl enable ohmyfeedback.service

info "Waiting for the service to boot up"
i=1
max_tries=10
while ! curl --fail -sS --connect-timeout 0.5 --max-time 1 http://127.0.0.1:80 ; do
  sleep 1
  ((i++))
  if ((i > max_tries)) ; then
    break
  fi
done

info "Last few lines of the service log"
since_timestamp="$($sudo systemctl show ohmyfeedback.service -p ActiveExitTimestamp --value)"
$sudo journalctl --unit=ohmyfeedback.service "--since=$since_timestamp" --no-pager

if ((i > max_tries)) ; then
  error "Service failed to start within given amount of retries ($max_tries)"
  exit 2
fi
info "All done"
