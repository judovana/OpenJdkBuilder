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

source ${SCRIPT_DIR}/../tck/autoruns/common.sh

function parseArgsAndSetGlobalVars() {
  OJDK_VERSION=${1} #TODO: guess version from src tarball filename
  WORKSPACE_DIR=${2}

  EXTRA_BUILD_PARAMS=
  if [[ ! x${3} == x ]]; then
    EXTRA_BUILD_PARAMS=${3}
  fi
  echo $EXTRA_BUILD_PARAMS

  if isWindows; then
    RAMDISK_DIR=/cygdrive/r
  else
    RAMDISK_DIR=/mnt/ramdisk
  fi
  if [ ! -e "${RAMDISK_DIR}" ] ; then
    echo "Warning RAMDISK_DIR=${RAMDISK_DIR}  do not exists. Swapping to temp:"
    RAMDISK_DIR=`mktemp -d`
    echo "RAMDISK_DIR=${RAMDISK_DIR}"
  fi

  SOURCE_DIR=${RAMDISK_DIR}/openjdk
  BUILDROOT=${RAMDISK_DIR}/buildroot
  BOOTJDK_DIR=~/bootjdk
  BOOTJDK_ARCHIVE_DIR=/mnt/shared/jdk-images/bootjdk/${OJDK_VERSION}
  SOURCE_ARCHIVE_DIR="${WORKSPACE_DIR}/rpms"
  SOURCE_ARCHIVE=`ls ${SOURCE_ARCHIVE_DIR}`
  BUILDSCRIPT=${WORKSPACE_DIR}/build.sh
  BUILD_RESULT=1

  LOGS_DIR=${RAMDISK_DIR}
  OTHER_LOGS_ARCHIVE_DIR=${WORKSPACE_DIR}/other_logs
  LOG_ALL_FILEPATH=${LOGS_DIR}/build.all.log
  LOG_OUT_FILEPATH=${LOGS_DIR}/build.out.log
  LOG_ERR_FILEPATH=${LOGS_DIR}/build.err.log
  LOG_PATCH_FILEPATH=${LOGS_DIR}/jdk-patching.log
}

function includeOjdkFunctions() {
  source ${SCRIPT_DIR}/${OJDK_VERSION}-functions.sh
}

function cleanRamdisk() {
  rm -rf ${RAMDISK_DIR}/* || true
}

function cleanWorkspace() {
  pushd ${WORKSPACE_DIR}
    rm -rf `ls | grep -v '^rpms$'`
  popd
}

function unpackSources() {
  mkdir -p ${SOURCE_DIR}
  tar --strip-components=1 -xf ${SOURCE_ARCHIVE_DIR}/* -C ${SOURCE_DIR}
}

function patchSources() {
  pushd ${SOURCE_DIR}
    rm -f ${LOG_PATCH_FILEPATH}

    # Apply every patch on Windows
    PATCHES=`ls ${SCRIPT_DIR}/patches/${OJDK_VERSION}/*.patch`
    if isLinux; then
      # Apply just patches that don't contain "windows" in filename
      PATCHES=`ls ${SCRIPT_DIR}/patches/${OJDK_VERSION}/*.patch | grep -v windows`
    fi

    for PATCH_FILE in ${PATCHES}
    do
      if [[ -f ${PATCH_FILE} ]]; then
        echo "Warning! applying patch: ${PATCH_FILE}"  2>&1 | tee -a ${LOG_PATCH_FILEPATH}
        patching=0
        patch -f -p1 < ${PATCH_FILE} 2>&1 | tee -a ${LOG_PATCH_FILEPATH} || patching=1 ;
        if [ $patching -eq 0 ] ; then
          echo "  OkOk warning, patch: ${PATCH_FILE}  APPLIED "  2>&1 | tee -a ${LOG_PATCH_FILEPATH}
        else
          echo "  XXXX warning! Error! patch ${PATCH_FILE} failed!" 2>&1 | tee -a ${LOG_PATCH_FILEPATH}
        fi
      fi
    done

  popd
}

function prepareLogs() {
  allLogs="${LOG_ERR_FILEPATH} ${LOG_OUT_FILEPATH} ${LOG_ALL_FILEPATH}"

  line1="`date`"
  line2="$ID $FILENAME1"
  line3="`uname -a`"
  for xlog in $allLogs ; do
    echo "$line1" > $xlog
    echo "$line2" >> $xlog
    echo "$line3" >> $xlog
  done
}

function prepareBuildRoot() {
  rm -rf ${BUILDROOT}
  mkdir -p ${BUILDROOT}
}

function build() {
  pushd ${BUILDROOT}
    set -o pipefail
    { { { sh ${BUILDSCRIPT} 2>&1 1>&3; } | tee -a ${LOG_ERR_FILEPATH}; }  3>&1 1>&2 |  tee -a ${LOG_OUT_FILEPATH}; } 2>&1 | tee -a  ${LOG_ALL_FILEPATH}
    BUILD_RESULT=$?
    set +o pipefail
  popd
}

function archiveResults() {
  pushd ${WORKSPACE_DIR}
    if [[ `uname -s` == *NT* ]]; then
      ARCH="win"
    else
      ARCH=`uname -m`
    fi

    BUILT_ARCHIVE_FILENAME=`echo ${SOURCE_ARCHIVE} | sed s/\.src\./.${ARCH}./`
    BUILT_ARCHIVE_FILENAME=`echo ${BUILT_ARCHIVE_FILENAME} | sed s/upstream/static/`

    BUILT_IMAGE_DIR="${BUILDROOT}/`getImageDir`"

    if [ ${BUILD_RESULT} -eq 0 ] && [ -d ${BUILT_IMAGE_DIR} ]; then
      tar -cJf ${BUILT_ARCHIVE_FILENAME} -C ${BUILT_IMAGE_DIR}/.. `basename ${BUILT_IMAGE_DIR}`
    else
      touch ${BUILT_ARCHIVE_FILENAME}
    fi
    cp ${RAMDISK_DIR}/*.log .
    cp ${BUILDSCRIPT} .

    mkdir ${OTHER_LOGS_ARCHIVE_DIR}
    find ${SOURCE_DIR} -name "*.log" -exec cp --parents {} ${OTHER_LOGS_ARCHIVE_DIR} \;
    find ${BUILDROOT} -name "*.log" -exec cp --parents {} ${OTHER_LOGS_ARCHIVE_DIR} \;
    tar czf other_logs.tar.gz ${OTHER_LOGS_ARCHIVE_DIR}

    # this should convert our big logs to truncated htmls
    rm -f *.html
    sh ${SCRIPT_DIR}/../jenkins/static/analyseLogs.sh build.???.log ???-patching.log
    sed  -i  "s;<body>;<body><h1>$FILENAME2</h1><h1>`date`</h1><a href='build.sh'>make call</a>;"  *.html
  popd
}

function cleanup() {
  cleanRamdisk
  if [ ! "x$PRESERVE_BUILD_WORKSPACE" == "xTRUE" ] ; then
    cleanWorkspace
  fi
}

function prepareSources() {
  unpackSources
  patchSources
}

function installBootJDK() {
  if [ ! "x$ALTERNATE_BOOT_JDK" == "x" ] ; then
    BOOTJDK_DIR=$ALTERNATE_BOOT_JDK
    return 0
  fi
  rm -rf ${BOOTJDK_DIR}
  mkdir -p ${BOOTJDK_DIR}
  if isWindows; then
    tar --strip-components=1 -xf ${BOOTJDK_ARCHIVE_DIR}/*win.tarxz -C ${BOOTJDK_DIR}
  else
    ARCH=$( uname -m )
    tar --strip-components=1 -xf ${BOOTJDK_ARCHIVE_DIR}/*${ARCH}.tarxz -C ${BOOTJDK_DIR}
  fi
}

function prepareBuild() {
  prepareLogs
  prepareBuildRoot
  generateBuildScript "${EXTRA_BUILD_PARAMS}"
}

parseArgsAndSetGlobalVars "${@}"
includeOjdkFunctions
cleanup
prepareSources
installBootJDK
#github only!!!
#installBuildDeps
prepareBuild
build
archiveResults
cleanRamdisk

exit ${BUILD_RESULT}
