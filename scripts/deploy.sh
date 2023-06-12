#!/usr/bin/env bash

set -euo pipefail

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${script_dir}/terraform.sh"
terraform

scp "${ssh_args[@]}" \
  "${script_dir}/remote-admin-deploy.sh" \
  "${server}:/ohmyfeedback/deploy/"

#scp "${ssh_args[@]}" "${script_dir}/../app/build/libs/app-all.jar" "${server}:/ohmyfeedback/deploy/" &

#wait "$(jobs -p)"
#ssh -t "${ssh_args[@]}" "$server" '/ohmyfeedback/deploy/remote-admin-deploy.sh'
