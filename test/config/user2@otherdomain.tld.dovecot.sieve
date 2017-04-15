require ["copy", "vnd.dovecot.pipe"];
if header :contains "subject" "Sieve pipe test message" {
  pipe :copy "pipe_to_tmp";
}
