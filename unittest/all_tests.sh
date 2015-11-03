#!/bin/sh

#
# Run all unit tests
#

echo "Running biotypemapping tests"
./biotypemapping_tests.py  || exit 1;
