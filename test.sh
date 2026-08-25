#!/bin/bash

set -eu

function error() {
  echo "Error: $*" 1>&2;
}


function main() {
  if [[ ! -e test.sh ]] || [[ ! -d lib ]] || [[ ! -d t ]]; then
    error "Not in project rootdir. Change to that dir"
    exit 1
  fi
  ROOTDIR=$PWD

  unset PERL5LIB
  export PERL5LIB="$ROOTDIR/lib"

  case ${1:-all} in
    "grepdocs"|"all")
      test_grepdocs
      ;;&
    "publish"|"all")
      test_publish
      ;;&
    "grepdocs"|"publish"|"all")
      # Catch all good args.
      ;;
    *)
      error "Unsupported test: $1"
      exit 1
      ;;
  esac

  echo "========================================"
  echo "All tests pass!"
  echo "========================================"
  echo "Have a nice day."
}


function test_grepdocs() {
  echo "Test grepdocs.pl"

  # Configure test config
  cat << EOL > t/grepdocs.ini
[TestDocs]
dir=$ROOTDIR/t/docs

[Version]
v=1
EOL

  # Run tests
  echo "Test --help"
  $ROOTDIR/grepdocs.pl --help > /dev/null
  echo "Done"

  echo "Test printing default config"
  $ROOTDIR/grepdocs.pl --default-config > /dev/null
  echo "Done"

  echo "Test grep"
  $ROOTDIR/grepdocs.pl --config t/grepdocs.ini foobar
  echo "Done"

  echo "All grepdocs.pl tests pass"
}


function test_publish() {
  echo "Test publish.pl"

  # Run tests
  echo "Test --help"
  $ROOTDIR/publish.pl --help > /dev/null
  echo "Done"

  echo "Test printing default config"
  $ROOTDIR/publish.pl --default-config > /dev/null
  echo "Done"

  echo "All publish.pl tests pass"
}


main $@
