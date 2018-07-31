#!/usr/bin/env bash
# postsrsd-wrapper.sh, version 0.2.2

if [ -n "$SRS_DOMAINNAME" ]; then
  domain_name="$SRS_DOMAINNAME"
elif [ -n "$OVERRIDE_HOSTNAME" ]; then
  domain_name="${OVERRIDE_HOSTNAME#*.}"
elif [ -n "$DOMAINNAME" ]; then
  domain_name="$DOMAINNAME"
else
  domain_name=$(hostname -d)
fi

sed -i -e "s/localdomain/${domain_name}/g" /etc/default/postsrsd

postsrsd_secret_file='/etc/postsrsd.secret'
postsrsd_state_dir='/var/mail-state/etc-postsrsd'
postsrsd_state_secret_file="${postsrsd_state_dir}/postsrsd.secret"

generate_secret() {
  ( umask 0077
    dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 -w0 > "$1" )
}

if [ -n "$SRS_SECRET" ]; then
  ( umask 0077
    echo "$SRS_SECRET" | tr ',' '\n' > "$postsrsd_secret_file" )
else
  if [ "$ONE_DIR" = 1 ]; then
    if [ ! -f "$postsrsd_state_secret_file" ]; then
      install -d -m 0775 "$postsrsd_state_dir"
      generate_secret "$postsrsd_state_secret_file"
    fi
    install -m 0400 "$postsrsd_state_secret_file" "$postsrsd_secret_file"
  elif [ ! -f "$postsrsd_secret_file" ]; then
    generate_secret "$postsrsd_secret_file"
  fi
fi

if [ -n "$SRS_EXCLUDE_DOMAINS" ]; then
  sed -i -e "s/^#\?SRS_EXCLUDE_DOMAINS=.*$/SRS_EXCLUDE_DOMAINS=$SRS_EXCLUDE_DOMAINS/g" /etc/default/postsrsd
fi

/etc/init.d/postsrsd start
