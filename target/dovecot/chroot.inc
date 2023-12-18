# This file removes `chroot` environments that
#
# 1. are not strictly needed
# 2. can cause problems
#
# See https://github.com/docker-mailserver/docker-mailserver/pull/3208#pullrequestreview-1366106516
# and it's related PRs.

service aggregator {
  chroot =
}

service anvil {
  chroot =
}

service director {
  chroot =
}

service ipc {
  chroot =
}

service old-stats {
  chroot =
}

service imap-login {
  chroot =
}

service managesieve-login {
  chroot =
}

service pop3-login {
  chroot =
}

service submission-login {
  chroot =
}

service imap-urlauth-login {
  chroot =
}
