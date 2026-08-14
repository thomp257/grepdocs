#!/bin/bash
set -eu

THIS_LIBINSTALL=${LIBINSTALL:-$HOME/opt/perl/lib}

if [[ ! -d "$THIS_LIBINSTALL" ]]; then
  echo "Did not find dir $THIS_LIBINSTALL" 1>&2
  echo "Please set \$LIBINSTALL to a directory or create the default" 1>&2
  exit 1
fi

cp -vr lib/* "$THIS_LIBINSTALL"

installer.sh grepdocs.pl
