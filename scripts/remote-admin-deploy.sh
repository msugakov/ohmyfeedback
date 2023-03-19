#!/usr/bin/env bash

set -euo pipefail

sudo=sudo

color_green="\033[0;32m"
color_off="\033[0m"
if [[ ! -t 1 ]]; then
  color_green=""
  color_off=""
fi

function info() {
  echo -e "$(date --iso-8601=seconds) [INFO] ${color_green}$@${color_off}"
}

info "Stopping old service"
$sudo systemctl stop ohmyfeedback.service

info "Copying over new jar"
cp -v /ohmyfeedback/deploy/app-all.jar /ohmyfeedback/dist/app-all.jar

info "Starting new service"
$sudo systemctl start ohmyfeedback.service

info "Enabling service start on reboot"
$sudo systemctl enable ohmyfeedback.service
