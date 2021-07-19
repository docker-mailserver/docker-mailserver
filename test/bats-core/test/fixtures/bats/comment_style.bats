function should_be_found { # @test
  true
}

function should_be_found_with_trailing_whitespace { # @test   
  true
}

should_be_found_with_parens() { #@test
  true
}

should_be_found_with_parens_and_whitespace () { #@test
  true
}

function should_be_found_with_function_and_parens() { #@test
  true
}

function should_be_found_with_function_parens_and_whitespace () { #@test
  true
}

should_not_be_found() { 
  false                                          
  #@test                                        
}                                               

should_not_be_found() {  
  false                   
} #@test   
