# Allow clients to use these additional mechanisms:
auth_mechanisms = $auth_mechanisms gssapi

auth_krb5_keytab = /etc/krb5.keytab
auth_default_realm =
auth_realms =
auth_gssapi_hostname =

# This provider uses the same config as the LDAP one because
# it depends on the LDAP pre-requisite (k5principals) to match
# users.
passdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
  mechanisms = gssapi
  default_fields = nopassword=y
}
