# OpenJdkBuilder
Set of scripts for building and publishing OpenJDK builds

Exemplar usage:
```bash
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
if [ "x$WORKSPACE" = "x" ] ; then
  readonly SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"
else
  readonly SCRIPT_DIR="$WORKSPACE"
fi


set -e
set -x
set -o pipefail
set -u


readonly TOOLSET="OpenJdkBuilder"
readonly TURL=https://github.com/judovana/$TOOLSET.git
if [ -e $TOOLSET ] ; then
  pushd $TOOLSET
    git pull
  popd
else
  git clone $TURL
fi

#removing old, wrongly named repository
rm -rf java-1.8.0-openjdk-jdk8u-shenandoah

readonly PROJECT_REPO=jdk8u-shenandoah
readonly PROJECT=aarch64-port
readonly TARGET_PROJECT=java-1.8.0-openjdk-aarch64-shenandoah
readonly URL=http://hg.openjdk.java.net/$PROJECT/$PROJECT_REPO
readonly repos="corba hotspot jaxp jaxws jdk langtools nashorn"

if [ ! -e $TARGET_PROJECT ] ; then
  hg clone $URL $TARGET_PROJECT
  pushd $TARGET_PROJECT
  for repo in $repos ; do
    hg clone $URL/$repo
  done
  popd
fi


export NO_UPLOAD="TRUE"
export ALTERNATIVE_DESTINATION="nobody@nowhere"
export UPSTREAM_REPOS_PATH=`pwd`
export NO_CHANGE_RETURN=-1
sh $SCRIPT_DIR/OpenJdkBuilder/jenkins/static/tempt-ojdk-repo.sh $TARGET_PROJECT 
#readonly tempt_jdk_result=$?
#would be worthy to usually stop here after tempt is done, and no change found...

rm -rf rpms
mkdir rpms
MAIN_SRC_FILE=`ls | grep -v fastdebug | grep "\.tarxz$"`
cp $MAIN_SRC_FILE rpms

export ALTERNATE_BOOT_JDK=/usr/lib/jvm/java-1.8.0-openjdk
export PRESERVE_BUILD_WORKSPACE="TRUE"
rm -rf build
mkdir  build
pushd build
mkdir  buildoutput
mv ../rpms buildoutput 
sh $SCRIPT_DIR/OpenJdkBuilder/build-ojdk/build-ojdk.sh "ojdk8" "$PWD/buildoutput" "--with-extra-cxxflags=-Wno-error -with-extra-cflags=-Wno-error --with-milestone=adoptopenjdk "
popd
# move our tag.changesets-repo.arch.tarxz to AdoptOpenJdk naming conventions
# waring hardcoded values and cross-jdk incompatible changes
readonly TIMESTAMP="$(date +'%Y%d%m%H%M')"
# hardcoded major version and platform (architecture and os)
readonly FILENAME="OpenJDK8_aarch64_Linux_$TIMESTAMP.tar.gz"
# hardcoded fake tag
if [ "x$TAG" == "x" ] ; then
  readonly ENFORCED_TAG=noTag
else
  readonly ENFORCED_TAG=$TAG
fi
tar -xf build/buildoutput/*.tarxz
mv j2sdk-image $ENFORCED_TAG
tar -czf  $FILENAME  $ENFORCED_TAG
rm -r $ENFORCED_TAG
```
