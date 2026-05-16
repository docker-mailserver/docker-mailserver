auth_master_user_separator = *

passdb passdb-master {
  master                  = yes
  driver                  = passwd-file
  passwd_file_path        = /etc/dovecot/masterdb
  auth_username_format    = %{user}
  default_password_scheme = SHA512-CRYPT
  result_success          = continue

  # Required for LDAP
  #auth_bind = yes
}
