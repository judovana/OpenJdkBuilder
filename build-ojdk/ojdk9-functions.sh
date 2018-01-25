function prepareBuildArgs() {
  WIN_SET=
  WIN_DEPS=
  DEBUG_OPTS=
  STATIC_OPTS=
  BUILD_OPTS="--with-native-debug-symbols=zipped  --disable-warnings-as-errors --with-boot-jdk=/usr/lib/jvm/java --enable-unlimited-crypto"
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
    WIN_DEPS="--with-freetype=/home/tester/freetype-lib"
  fi
}

# TODO: accept source dir param. If not provided use ${SOURCE_DIR}
function generateBuildScript() {
  prepareBuildArgs "$@"

  rm -rf ${BUILDSCRIPT}
  echo "#/bin/bash" >> ${BUILDSCRIPT}
  echo "# `date`"
  echo "OPENJDK_SRC=${SOURCE_DIR}" >> ${BUILDSCRIPT}
  echo "bash \${OPENJDK_SRC}/common/autoconf/autogen.sh" >> ${BUILDSCRIPT}

  echo ${WIN_SET} >> ${BUILDSCRIPT}

  echo "bash \${OPENJDK_SRC}/configure \
    ${STATIC_OPTS} \
    ${DEBUG_OPTS} \
    ${WIN_DEPS} \
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
    pushd /mnt/shared/jdk-images/windows_build_deps
    $COMMAND /i *.msi INSTALLDIR="c:\cygwin64\usr\lib\jvm\java" /quiet /Lv* c:\\javainstall.log

    # cygwin has /usr/lib just like symbolic link to /lib and windows path c:/cygwin64/usr does not exist.
    # We need both to exist because openjdk build first check whether boot java exists and then translate the path to windows path.
    mkdir -p /usr/lib/jvm && rm -rf /usr/lib/jvm/java && ln -s /cygdrive/c/cygwin64/usr/lib/jvm/java /usr/lib/jvm/java

    cp -r /mnt/shared/jdk-images/windows_build_deps/freetype-lib /home/tester/freetype-lib
    popd
  else
    sudo ${COMMAND} -y install java-1.8.0-openjdk-devel libstdc++-static
  fi
}

function getImageDir() {
  echo "images/jdk"
}
