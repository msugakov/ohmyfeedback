#!/usr/bin/env bash

set -euo pipefail

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

server="$(cat "${script_dir}/server")"
# Obtain with: ssh-keyscan 152.70.58.209 > server-keys
server_keys="${script_dir}/server-keys"

ssh_args=(
#  "-v"
  "-o" "StrictHostKeyChecking=yes"
  "-o" "UserKnownHostsFile=${server_keys}"
)

terraform() {
  ssh "${ssh_args[@]}" "$server" \
    'sudo mkdir -p /ohmyfeedback && sudo chown "$(id -u):$(id -g)" /ohmyfeedback && mkdir -p /ohmyfeedback/deploy'

  scp "${ssh_args[@]}" \
    "${script_dir}/../.ruby-version" \
    "${script_dir}/remote-admin-terraform.sh" \
    "${script_dir}/remote-admin-deploy.sh" \
    "${server}:/ohmyfeedback/deploy/"

  ssh -t "${ssh_args[@]}" "$server" '/ohmyfeedback/deploy/remote-admin-terraform.sh'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  terraform "$@"
fi
