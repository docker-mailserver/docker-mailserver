#! /bin/bash

# shellcheck disable=SC2034 # VAR appears unused.

function _rspamd_get_envs() {
  readonly RSPAMD_LOCAL_D='/etc/rspamd/local.d'
  readonly RSPAMD_OVERRIDE_D='/etc/rspamd/override.d'

  readonly RSPAMD_DMS_D='/tmp/docker-mailserver/rspamd'
  readonly RSPAMD_DMS_DKIM_D="${RSPAMD_DMS_D}/dkim"
  readonly RSPAMD_DMS_OVERRIDE_D="${RSPAMD_DMS_D}/override.d"
}
