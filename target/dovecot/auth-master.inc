auth_master_user_separator = *
passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u /etc/dovecot/masterdb
  master = yes
  result_success = continue
  #auth_bind = yes
}
