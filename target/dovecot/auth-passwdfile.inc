# Authentication for passwd-file users. Included from 10-auth.conf.
#
# Documentation
#   PassDB: https://doc.dovecot.org/configuration_manual/authentication/password_databases_passdb/
#   UserDB: https://doc.dovecot.org/configuration_manual/authentication/user_databases_userdb/
#
# !!! Attention !!!
#   Do not add `scheme=SHA512-CRYPT` to the userdb args. This is not supported.

passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u /etc/dovecot/userdb
}

userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/userdb
  default_fields = uid=docker gid=docker home=/var/mail/%d/%u/home/
}
