load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# load the helper function into current context
. ./target/helper_functions.sh

@test "check helper function: _sanitize_ipv4_to_subnet_cidr" {
    output=$(_sanitize_ipv4_to_subnet_cidr 255.255.255.255/0)
    assert_output "0.0.0.0/0"
    output=$(_sanitize_ipv4_to_subnet_cidr 192.168.255.14/20)
    assert_output "192.168.240.0/20"
    output=$(_sanitize_ipv4_to_subnet_cidr 192.168.255.14/32)
    assert_output "192.168.255.14/32"
}