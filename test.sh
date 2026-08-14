#!/bin/bash

set -eu

function error() {
  echo "Error: $*" 1>&2;
}


function main() {
  if [[ ! -e test.sh ]]; then
    error "Not in project rootdir. Change to that dir"
    exit 1
  fi
  ROOTDIR=$PWD

  unset PERL5LIB
  export PERL5LIB="$ROOTDIR/lib"

  test_grepdocs

  echo "All tests pass"
  echo "Have a nice day"
}


function test_grepdocs() {
  # Make test config
  cat << EOL > t/grepdocs.ini
[TestDocs]
dir=$ROOTDIR/t/docs

[Version]
v=1
EOL

  # Run tests
  echo "Test printing default config"
  $ROOTDIR/grepdocs.pl --config t/grepdocs.ini --default-config > /dev/null

  echo "Test grep"
  $ROOTDIR/grepdocs.pl --config t/grepdocs.ini foobar

  echo "All grepdocs tests pass"
}


main $@
