function prepareBuildArgs() {
  WIN_SET=
  WIN_DEPS=
  DEBUG_OPTS=
  STATIC_OPTS=
  BUILD_OPTS="$@"

  BUILDROOT_DIR=buildroot
  if [[ ${SOURCE_ARCHIVE} = *.fastdebug.* ]] ; then
    DEBUG_OPTS="DEBUG_CLASSFILES=true DEBUG_BINARIES=true SKIP_FASTDEBUG_BUILD=false DEBUG_NAME=fastdebug"
    BUILDROOT_DIR=buildroot-fastdebug
  elif [[ ${SOURCE_ARCHIVE} = *.slowdebug.* ]] ; then
    #this is probably doing nothing
    DEBUG_OPTS="DEBUG_CLASSFILES=true DEBUG_BINARIES=true SKIP_FASTDEBUG_BUILD=false DEBUG_NAME=slowdebug"
  else
    DEBUG_OPTS="DEBUG_CLASSFILES=true DEBUG_BINARIES=true SKIP_FASTDEBUG_BUILD=true"
  fi
  #half of those  is probably not working or overwtite anyway, but static build seemed to be transferable well
  if [[ ${SOURCE_ARCHIVE} = *.upstream.* || ${SOURCE_ARCHIVE} = *.static.* ]] ; then
    STATIC_OPTS="STATIC_CXX=true
   SYSTEM_LCMS=false
   SYSTEM_ZLIB=false
   SYSTEM_JPEG=false
   SYSTEM_PNG=false
   SYSTEM_GIF=false
   SYSTEM_KRB5=false
   SYSTEM_CUPS=false
   SYSTEM_FONTCONFIG=false
   SYSTEM_PCSC=false
   SYSTEM_SCTP=false
  "
  else
    STATIC_OPTS="STATIC_CXX=false
    SYSTEM_LCMS=true
    SYSTEM_ZLIB=true
    SYSTEM_JPEG=true
    SYSTEM_PNG=true
    SYSTEM_GIF=true
    SYSTEM_KRB5=true
    SYSTEM_CUPS=true
    SYSTEM_FONTCONFIG=true
    SYSTEM_PCSC=true
    SYSTEM_SCTP=true
  "
  fi

  WIN_PATCHES=""
  OTHER_OPTS=""
  if isWindows; then
    OTHER_OPTS="HOTSPOT_IMPORT_PATH=R:/${BUILDROOT_DIR}/hotspot/import
    HOTSPOT_SERVER_PATH=R:/${BUILDROOT_DIR}/hotspot/import/jre/bin/server
    HOTSPOT_LIB_PATH=R:/${BUILDROOT_DIR}/hotspot/import/lib
    LANGTOOLS_DIST=R:/${BUILDROOT_DIR}/langtools/dist
    CORBA_DIST=R:/${BUILDROOT_DIR}/corba/dist
    JAXP_DIST=R:/${BUILDROOT_DIR}/jaxp/dist
    JAXWS_DIST=R:/${BUILDROOT_DIR}/jaxws/dist
    ALT_FREETYPE_LIB_PATH=C:/cygwin64/home/tester/freetype-lib/lib
    ALT_FREETYPE_HEADERS_PATH=C:/cygwin64/home/tester/freetype-lib/include
    ALT_BOOTDIR=C:/cygwin64/usr/lib/jvm/java
    ALT_OUTPUTDIR=R:/buildroot
    "
    WIN_PATCHES="/mnt/shared/TckScripts/jenkins/static/java-1.7.0-openjdk-windows-path-check.patch"
  else
    OTHER_OPTS="
      FT2_CFLAGS=\"\`pkg-config --cflags freetype2\`\"
      FT2_LIBS=\"\`pkg-config --libs freetype2\`\"
    "
  fi
}

# TODO: accept source dir param. If not provided use ${SOURCE_DIR}
function generateBuildScript() {
  prepareBuildArgs "$@"

  rm -rf ${BUILDSCRIPT}

  echo "#/bin/bash" >> ${BUILDSCRIPT}
  echo "# `date`"
  echo "OPENJDK_SRC=${SOURCE_DIR}" >> ${BUILDSCRIPT}

  echo "export LCMS_CFLAGS=disabled
  export LCMS_LIBS=disabled

  VARS=\"
  UNLIMITED_CRYPTO=true
  ANT=/usr/bin/ant
  ALT_BOOTDIR=/usr/lib/jvm/java
  ALT_OUTPUTDIR=\$PWD
  $STATIC_OPTS
  $DEBUG_OPTS
  $OTHER_OPTS
  $BUILD_OPTS
  \"

  for VAR in \$VARS ; do
    export \$VAR
  done

  source \${OPENJDK_SRC}/jdk/make/jdk_generic_profile.sh

  for VAR in \$VARS ; do
    export \$VAR
  done
  set +o pipefail
  make -C \${OPENJDK_SRC} \$VARS
  " >> ${BUILDSCRIPT}
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

  if [ $COMMAND == msiexec ]; then
    pushd /mnt/shared/jdk-images/windows_build_deps
    rm -rf /cygdrive/c/cygwin64/usr/lib/jvm/java
    mkdir -p /cygdrive/c/cygwin64/usr/lib/jvm/java
    tar -xf /mnt/shared/jdk-images/windows_build_deps/jdk6-oracle.tar.gz -C /cygdrive/c/cygwin64/usr/lib/jvm/java
    ln -s -f /cygdrive/c/cygwin64/usr/lib/jvm/java /cygdrive/c/jdk1.6.0

    rm -rf /opt/apache-ant-1.7.1 && mkdir -p /opt/apache-ant-1.7.1
    tar -xf /mnt/shared/jdk-images/windows_build_deps/apache-ant-1.7.1.tar.gz -C /opt/apache-ant-1.7.1
    chmod +x /opt/apache-ant-1.7.1/bin/ant
    ln -s -f /opt/apache-ant-1.7.1/bin/ant /usr/bin/ant

    cp /mnt/shared/jdk-images/windows_build_deps/vcvars64.bat "/cygdrive/c/Program Files (x86)/Microsoft Visual Studio 10.0/VC/bin/amd64"
    eval `cat /mnt/shared/jdk-images/windows_build_deps/vars_settings`

    # cygwin has /usr/lib just like symbolic link to /lib and windows path c:/cygwin64/usr does not exist.
    # We need both to exist because openjdk build first check whether boot java exists and then translate the path to windows path.
    mkdir -p /usr/lib/jvm && rm -rf /usr/lib/jvm/java && ln -s /cygdrive/c/cygwin64/usr/lib/jvm/java /usr/lib/jvm/java

    cp -r /mnt/shared/jdk-images/windows_build_deps/freetype-lib /home/tester/freetype-lib
    popd
  else
    sudo ${COMMAND} -y install java-1.6.0-openjdk-devel redhat-lsb ant ant-nodeps pkgconfig
  fi
}

function getImageDir() {
  if [[ ${SOURCE_ARCHIVE} = *.fastdebug.* ]] ; then
    echo "../`basename ${BUILDROOT}`-fastdebug/j2sdk-image"
  else
    echo "j2sdk-image"
  fi
}
