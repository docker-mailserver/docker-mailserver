# Authentication for passwd-file users. Included from 10-auth.conf.
#
# passwd-like file with specified location.
# <doc/wiki/AuthDatabase.PasswdFile.txt>

passdb {
  driver = passwd-file
  args = scheme=CRYPT username_format=%u /etc/dovecot/userdb
}

userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/userdb

  # Default fields that can be overridden by passwd-file
  #default_fields = quota_rule=*:storage=1G
  default_fields = uid=docker gid=docker home=/var/mail/%d/%u

  # Override fields from passwd-file
  #override_fields = home=/home/virtual/%u
}
