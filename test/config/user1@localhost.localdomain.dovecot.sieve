require ["copy", "envelope", "vnd.dovecot.pipe"];
if envelope :is "from" "sieve.pipe@test.localdomain" {
  pipe :copy "pipe_to_tmp";
}
