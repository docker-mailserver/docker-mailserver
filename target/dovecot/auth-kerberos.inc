# Allow clients to use these additional mechanisms:
auth_mechanisms = $auth_mechanisms gssapi

userdb {
  driver = ldap
  mechanisms = gssapi
  default_fields = uid=docker gid=docker home=/var/mail/%d/%u/home/
}
