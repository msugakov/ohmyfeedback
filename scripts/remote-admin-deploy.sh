#!/usr/bin/env bash

set -euo pipefail

sudo=sudo

service_user="$(id -u ohmyfeedback)"
service_group="$(id -g ohmyfeedback)"

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

info "Refreshing TLS certificate if needed"
# Use --test-cert for fiddling with commands while testing/debugging but remove it for production.
$sudo certbot --standalone \
  --config-dir /ohmyfeedback/certbot \
  --work-dir /ohmyfeedback/certbot \
  --logs-dir /ohmyfeedback/certbot \
  -m info@ohmyfeedback.net \
  -d ohmyfeedback.net,ohmyfeedbacks.net \
  -n --agree-tos \
  certonly

info "Converting TLS certificate for Java usage"
java_staging="/ohmyfeedback/certbot/for-java"
$sudo cp /ohmyfeedback/certbot/live/ohmyfeedback.net/{fullchain.pem,privkey.pem} "$java_staging"
$sudo chgrp "$(id -g)" "$java_staging/privkey.pem"
$sudo chmod g+r "$java_staging/privkey.pem"
openssl rand 40 | openssl enc -nopad -A -base64 > "$java_staging/conversion-pass"
openssl pkcs12 -export \
  -in "$java_staging/fullchain.pem" \
  -inkey "$java_staging/privkey.pem" \
  -out "$java_staging/keystore.p12" \
  -name "sampleAlias" -passout file:"$java_staging/conversion-pass" </dev/null
# Remove output .jks file because otherwise keytool will try to append to an existing one.
rm -vf "$java_staging/keystore.jks"
openssl rand 48 | openssl enc -nopad -A -base64 > "$java_staging/keystore.jks-pass"
keytool -importkeystore \
  -srckeystore "$java_staging/keystore.p12" -srcstoretype pkcs12 \
  -srcstorepass:file "$java_staging/conversion-pass" \
  -destkeystore "$java_staging/keystore.jks" \
  -deststorepass:file "$java_staging/keystore.jks-pass" </dev/null
chmod 640 "$java_staging/keystore.jks" "$java_staging/keystore.jks-pass"
$sudo chgrp "$service_group" "$java_staging/keystore.jks" "$java_staging/keystore.jks-pass"
mv -v "$java_staging/keystore.jks" "$java_staging/keystore.jks-pass" "/ohmyfeedback/secrets"

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
