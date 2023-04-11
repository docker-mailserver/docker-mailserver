service lmtp {
  unix_listener lmtp {
    mode = 0660
    group = postfix
  }

  # Create inet listener only if you can't use the above UNIX socket
  # and avoid making LMTP visible for the entire internet
  #inet_listener lmtp {
  #  address = 127.0.0.1
  #  port = 24
  #}
}
