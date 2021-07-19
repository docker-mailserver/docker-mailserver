@test "no extra whitespace" {
  :
}

	@test "tab at beginning of line" {
	  :
	}

@test	"tab before description" {
  :
}

@test "tab before opening brace"	{
  :
}

	@test	"tabs at beginning of line and before description" {
	  :
	}

	@test	"tabs at beginning, before description, before brace"	{
	  :
	}

	 @test	 "extra whitespace around single-line test"	 {	 :;	 }	 

@test "no extra whitespace around single-line test" {:;}

@test	 parse unquoted name between extra whitespace 	{:;}

@test { {:;}  # unquote single brace is a valid description

@test ' {:;}  # empty name from single quote
