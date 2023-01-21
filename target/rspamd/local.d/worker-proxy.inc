# documentation: https://rspamd.com/doc/workers/rspamd_proxy.html
# see also: https://rspamd.com/doc/quickstart.html#using-of-milter-protocol-for-rspamd--16

bind_socket = "127.0.0.1:11332";

milter = yes;
timeout = 120s;

upstream "local" {
  default = yes;
  self_scan = yes;
}

count = 2;
max_retries = 5;
discard_on_reject = false;
quarantine_on_reject = false;
spam_header = "X-Spam";
