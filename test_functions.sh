#!/bin/bash

# Test script for CandyHole functions
# This tests individual functions without full system setup

source ./CandyHole.sh

echo "Testing CandyHole functions..."

# Test color functions (should not error)
echo "Testing color functions:"
print_info "Info message test"
print_success "Success message test"
print_warning "Warning message test"
print_error "Error message test"
print_header "Header Test"

# Test IP validation
echo ""
echo "Testing IP validation:"
test_ips=("192.168.1.1" "255.255.255.255" "0.0.0.0" "256.1.1.1" "invalid.ip" "192.168.1")

for ip in "${test_ips[@]}"; do
    if validate_ip "$ip"; then
        echo "✓ $ip is valid"
    else
        echo "✗ $ip is invalid"
    fi
done

# Test port validation
echo ""
echo "Testing port validation:"
test_ports=("8080" "80" "65535" "0" "65536" "invalid")

for port in "${test_ports[@]}"; do
    if validate_port "$port"; then
        echo "✓ $port is valid"
    else
        echo "✗ $port is invalid"
    fi
done

echo ""
echo "Function tests completed!"
