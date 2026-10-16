#!/bin/bash
set -euo pipefail


function main() {
  if [[ ! -e test.sh ]] || [[ ! -d lib ]] || [[ ! -d t ]]; then
    error "Not in project rootdir. Change to that dir"
    exit 1
  fi
  ROOTDIR=$PWD

  # Set perl lib to just this project's contents.
  unset PERL5LIB
  export PERL5LIB="$ROOTDIR/lib"

  make_test_config

  case ${1:-all} in
    grepdocs*|"all")
      test_grepdocs
      ;;&
    publish*|"all")
      test_publish
      ;;&
    grepdocs*|publish*|all)
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


function make_test_config() {
  # Make a config file for testing.
  cat << EOL > t/grepdocs.ini
[TestDocs]
dir=$ROOTDIR/t/docs
publish=$ROOTDIR/t/publish/html

[NextTestDocs]
dir=$ROOTDIR/t/docs2
publish=$ROOTDIR/t/publish/html

[NoPublish]
dir=$ROOTDIR/t/docs/empty

[Version]
v=2
EOL
}


function test_grepdocs() {
  echo "Test grepdocs.pl"

  # Run tests
  iecho "Test --version and --help"
  $ROOTDIR/grepdocs.pl --version
  $ROOTDIR/grepdocs.pl --help > /dev/null

  iecho "Test printing default config"
  $ROOTDIR/grepdocs.pl --default-config > /dev/null

  iecho "Test grep filename is first"
  $ROOTDIR/grepdocs.pl --config t/grepdocs.ini testdoc2 | \
    head -n1 | grep -q "t/docs2/TestDoc2.md" \
    || fail

  iecho "Test grep search contents"
  $ROOTDIR/grepdocs.pl --config t/grepdocs.ini foobar | \
    wc -l | \
    grep -q "3" \
    || fail

  echo "All grepdocs.pl tests pass"
}


function test_publish() {
  echo "Test publish.pl"

  # Run tests
  iecho "Test --version and --help"
  $ROOTDIR/publish.pl --version
  $ROOTDIR/publish.pl --help > /dev/null

  iecho "Test printing default config"
  $ROOTDIR/publish.pl --default-config > /dev/null

  iecho "Test publish all files"
  # Clean-up any previous test results.
  rm -rf t/publish/html/*

  # Publish all docs.
  # - Check for 2 specific publishes.
  $ROOTDIR/publish.pl --config t/grepdocs.ini | \
    grep -cE "t/publish/html/doc3.html|t/publish/html/section1/foobar.html" | \
    grep -q "2" \
    || fail

  iecho "Verify publish skips newer files"
  $ROOTDIR/publish.pl --config t/grepdocs.ini -v | \
    grep -q "is newer than markdown" \
    || fail

  iecho "Test publish made html"
  grep -q "<title>Test Doc 1</title>" t/publish/html/doc1.html || fail

  echo "All publish.pl tests pass"
}


function error() {
  echo "Error: $*" 1>&2;
}


function fail() {
  iecho "Failed! $*";
  exit 1;
}


function iecho() {
  # Indent message 2 spaces.
  local indent="  "
  echo "${indent}$@"
}


main $@
