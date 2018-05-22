function prepareBuildArgs() {
  WIN_SET=
  WIN_OPTS=
  DEBUG_OPTS=
  STATIC_OPTS=
  BUILD_OPTS="--with-native-debug-symbols=zipped --disable-warnings-as-errors --with-boot-jdk=${BOOTJDK_DIR} --enable-unlimited-crypto"
  BUILD_OPTS="${BUILD_OPTS} $@"

  if [[ ${SOURCE_ARCHIVE} = *.fastdebug.* ]] ; then
    DEBUG_OPTS="--with-debug-level=fastdebug"
  elif [[ ${SOURCE_ARCHIVE} = *.slowdebug.* ]] ; then
    DEBUG_OPTS="--with-debug-level=slowdebug"
  else
    DEBUG_OPTS="--disable-debug-symbols --disable-zip-debug-info"
  fi

  if [[ ${SOURCE_ARCHIVE} = *.upstream.* || ${SOURCE_ARCHIVE} = *.static.* ]] ; then
    STATIC_OPTS="--with-giflib=bundled --with-stdcpplib=static"
  else
    STATIC_OPTS="--with-giflib=system --with-stdcpplib=dynamic"
  fi

  if isWindows; then
    WIN_SET="export TMP=C:\\\\Windows\\\\Temp && export TEMP=C:\\\\Windows\\\\Temp"
    WIN_OPTS="--with-num-cores=2 --with-memory-size=2048 --with-freetype=/home/tester/freetype-lib"
  fi
}

# TODO: accept source dir param. If not provided use ${SOURCE_DIR}
function generateBuildScript() {
  prepareBuildArgs "$@"

  rm -rf ${BUILDSCRIPT}
  echo "#/bin/bash" >> ${BUILDSCRIPT}
  echo "# `date`" >> ${BUILDSCRIPT}
  echo "OPENJDK_SRC=${SOURCE_DIR}" >> ${BUILDSCRIPT}
  echo "bash \${OPENJDK_SRC}/make/autoconf/autogen.sh" >> ${BUILDSCRIPT}

  echo ${WIN_SET} >> ${BUILDSCRIPT}

  echo "bash \${OPENJDK_SRC}/configure \
    ${STATIC_OPTS} \
    ${DEBUG_OPTS} \
    ${WIN_OPTS} \
    ${BUILD_OPTS}" >> ${BUILDSCRIPT}
  echo "set +o pipefail" >> ${BUILDSCRIPT}
  echo "make all bootcycle-images docs" >> ${BUILDSCRIPT}
}

function installBuildDeps() {
  COMMAND=
  if which dnf 1>/dev/null 2>&1
  then
    COMMAND=dnf
  elif which yum 1>/dev/null 2>&1
  then
    COMMAND=yum
  elif which msiexec 1>/dev/null 2>&1
  then
    COMMAND=msiexec
  fi

  if isWindows; then
    cp -r /mnt/shared/jdk-images/windows_build_deps/freetype-lib /home/tester/freetype-lib
  else
    sudo ${COMMAND} -y install libstdc++-static
  fi
}

function getImageDir() {
  echo "images/jdk"
}
