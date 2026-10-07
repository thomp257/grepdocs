#!/bin/bash
set -eu

THIS_LIBINSTALL=${LIBINSTALL:-$HOME/opt/perl/lib}

if [[ ! -d "$THIS_LIBINSTALL" ]]; then
  echo "Did not find dir $THIS_LIBINSTALL" 1>&2
  echo "Please set \$LIBINSTALL to a directory or create the default" 1>&2
  exit 1
fi

for FILE in $(find lib -depth -type f | sed 's#lib/##');
do
    installer.sh lib/$FILE "$THIS_LIBINSTALL/$FILE"
    echo -n '*'
done

installer.sh grepdocs.pl $HOME/bin/grepdocs.pl
echo -n '*'
installer.sh publish.pl $HOME/bin/publish.pl
echo -n '*'

echo " Done"
