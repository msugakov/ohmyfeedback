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

ssh "${ssh_args[@]}" "$server" 'mkdir -p /ohmyfeedback/deploy'
scp "${ssh_args[@]}" "${script_dir}/remote-admin-terraform.sh" "${script_dir}/remote-admin-deploy.sh" "${server}:/ohmyfeedback/deploy/"
scp "${ssh_args[@]}" "${script_dir}/../app/build/libs/app-all.jar" "${server}:/ohmyfeedback/deploy/" &
ssh -t "${ssh_args[@]}" "$server" '/ohmyfeedback/deploy/remote-admin-terraform.sh'

wait "$(jobs -p)"
ssh -t "${ssh_args[@]}" "$server" '/ohmyfeedback/deploy/remote-admin-deploy.sh'
