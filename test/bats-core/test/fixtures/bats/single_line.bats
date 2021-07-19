@test "empty" { }

@test "passing" { true; }

@test "input redirection" { diff - <( echo hello ); } <<EOS
hello
EOS

@test "failing" { false; }
