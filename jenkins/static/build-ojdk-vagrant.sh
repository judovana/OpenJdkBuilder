#!/bin/bash

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


if [ $# -lt 2 ] ; then
  echo 'expected two parameters' >&2
  echo 'usage: bash build-ojdk-vagrant.sh [vm-where-build] [ojdk7|ojdk8|ojdk9] "[extra_build_args]"' >&2
  echo 'third [extra_build_args] is optional'
  echo ''
  exit 1
fi

set -x

VM=${1}
OJDK_VERSION=${2}
EXTRA_BUILD_ARGS=${3}

if [[ x${VM} == xlocal ]]; then
  BUILD_WORKSPACE=$( pwd )
else
  BUILD_WORKSPACE=/mnt/workspace
fi

sh ${SCRIPT_DIR}/../vagrant/run.sh ${VM} "sh /mnt/shared/TckScripts/build-ojdk/build-ojdk.sh ${OJDK_VERSION} ${BUILD_WORKSPACE} \"${EXTRA_BUILD_ARGS}\""
BUILD_RESULT=$?

if [ ! "x$NO_UPLOAD" == "xTRUE"  ] ; then
  BUILT_ARCHIVE=`ls *.tarxz*`
  sh ${SCRIPT_DIR}/../../build-ojdk/upload-artifacts.sh ${BUILT_ARCHIVE} ${BUILD_RESULT}
fi

exit ${BUILD_RESULT}
