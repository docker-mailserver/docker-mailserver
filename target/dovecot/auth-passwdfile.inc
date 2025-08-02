# Authentication for passwd-file users. Included from 10-auth.conf.
#
# ref: https://doc.dovecot.org/main/core/config/auth/databases/passwd_file.html

passdb passwd-file {
  driver = passwd-file
  mechanisms_filter = plain login
  default_password_scheme = SHA512-CRYPT
  auth_username_format = %{user}
  passwd_file_path = /etc/dovecot/userdb
}

# !!! Attention !!!
#   Do not add `scheme=SHA512-CRYPT` to the userdb args. This is not supported.
userdb passwd-file {
  driver = passwd-file
  auth_username_format = %{user}
  passwd_file_path = /etc/dovecot/userdb
  # Defaults field values for an entry if they're missing in `/etc/dovecot/userdb`.
  # NOTE: That file is created from `postfix-accounts.cf` + `postfix-virtual.cf`
  fields {
    uid:default = docker
    gid:default = docker
    home:default = /var/mail/%{user | domain}/%{user | username}/home/
  }
}
