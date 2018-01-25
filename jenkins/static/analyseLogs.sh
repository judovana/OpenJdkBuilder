## resolve folder of this script, following all symlinks,
## http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
export readonly SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"




#!/bin/bash
export COLOUR=red
export AFTER=5
export BEFORE=5
export WORDS="fail failure error failed fails failures errors"
export FINAL_FILE=errors.html
sh $SCRIPT_DIR/analyseLogsImpl.sh ${@}


export COLOUR=yellow
export AFTER=1
export BEFORE=1
export WORDS="warning warnings"
export FINAL_FILE=warnings.html

sh $SCRIPT_DIR/analyseLogsImpl.sh ${@}

#change patches to links to make debugging more easy
URL=http://git.engineering.redhat.com/git/users/jvanek/TckScripts/.git/tree
DIR=/mnt/shared/TckScripts
for file in errors.html warnings.html ; do
  sed "s;$DIR/\(.*.patch\);<a href=\"$URL/\1\">$DIR/\1</a>;g" -i $file
done
