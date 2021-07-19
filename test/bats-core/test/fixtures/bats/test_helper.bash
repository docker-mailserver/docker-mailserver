help_me() {
  true
}

failing_helper() {
  false
}

return_0() {
  # Just return 0. Intentional assignment to boost line numbers
  result=0
  return $result
}

return_1() {
  # Just return 0. Intentional assignment to boost line numbers
  result=1
  return $result
}
