#!/bin/bash

set -x

## resolve folder of this script, following all symlinks,
## http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
readonly SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"

. $SCRIPT_DIR/../jenkins/custom_run_wrappers/parts/initMachines.sh

BUILT_ARCHIVE=${1}
BUILD_RESULT=${2}

BUILD_LOG=build.all.log

set -x
# DESTINATION is from initMachines.sh, and is user@machine, feel free change by ALTERNATIVE_DESTINATION
# if you dont specify user, default user from initMachines is used
if [ ! "x$ALTERNATIVE_DESTINATION" = "x" ] ; then
  DESTINATION=$ALTERNATIVE_DESTINATION
  if [[ ! $DESTINATION = *@* ]] ; then
    DESTINATION=$master_user@$DESTINATION
  fi
fi

if [ ${BUILD_RESULT} -eq 0 ] && [ -f $BUILT_ARCHIVE ] ; then
  scp -o StrictHostKeyChecking=no -P 9822  $BUILT_ARCHIVE $DESTINATION:
else
  touch FAILED
  scp -o StrictHostKeyChecking=no -P 9822 FAILED $DESTINATION:$BUILT_ARCHIVE/FAILED
  rm -rf FAILED
fi
if [ -f $BUILD_LOG ] ; then
  scp -o StrictHostKeyChecking=no -P 9822   *.log *.html build.sh $incomingLog $DESTINATION:$BUILT_ARCHIVE/logs
else
  touch FAILED
  scp -o StrictHostKeyChecking=no -P 9822 FAILED $DESTINATION:$BUILT_ARCHIVE/logs
  rm -rf FAILED
fi
