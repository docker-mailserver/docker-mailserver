# Authentication for passwd-file users. Included from 10-auth.conf.
#
# ref: https://doc.dovecot.org/main/core/config/auth/databases/passwd_file.html

passdb passdb-default {
  driver                  = passwd-file
  passwd_file_path        = /etc/dovecot/userdb
  auth_username_format    = %{user}
  mechanisms_filter       = plain login
  default_password_scheme = SHA512-CRYPT
}

userdb userdb-default {
  driver                  = passwd-file
  passwd_file_path        = /etc/dovecot/userdb
  auth_username_format    = %{user}

  # Default field values to use when they're not set for user accounts sourced via `/etc/dovecot/userdb`.
  # NOTE: That file is created from `postfix-accounts.cf` + `postfix-virtual.cf`
  fields {
    uid:default = docker
    gid:default = docker
    home:default = /var/mail/%{user | domain}/%{user}/home/
  }
}
