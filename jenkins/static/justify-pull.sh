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


##########################################################################
# welocme to Michal's fair scheduler algorithm!                          #
# Michal's note: I didn't wrote the code! I just invented the algorithm. #
##########################################################################

function curlMaster() {
  local job=$1
  # jenkins_jobs is from initMachines
  curl  --show-error $jenkins_jobs/$job/build
}

function executeJenkinsPullJobFor() {
  #repo
  local repo=$1
# map
#java-1.7.0-openjdk
#java-1.7.0-openjdk-forest
#java-1.8.0-openjdk
#java-1.8.0-openjdk-aarch64
#java-1.8.0-openjdk-aarch64-shenandoah
#java-1.8.0-openjdk-dev
#java-9-openjdk
#java-9-openjdk-dev
#java-9-openjdk-shenandoah
#java-1.7.0-openjdk-forest-26
#java-9-openjdk-updates
#java-X-openjdk
# to
#pull-ojdk7u-static
#pull-ojdk7-forest-static
#pull-ojdk8u-static
#pull-ojdk8u-dev-static
#pull-ojdk8u-aarch64-static
#pull-ojdk8u-aarch64-shenandoah-static
#pull-ojdk9-static
#pull-ojdk9-dev-static
#pull-ojdk9-shenandoah-static
#pull-ojdk7-forest-26-static
#pull-ojdk9-updates-static
#pull-ojdkX-static
if [ $repo = java-1.7.0-openjdk ]; then
  local job=pull-ojdk7u-static
elif [ $repo = java-1.7.0-openjdk-forest ]; then
  local job=pull-ojdk7-forest-static
elif [ $repo = java-1.8.0-openjdk ]; then
  local job=pull-ojdk8u-static
elif [ $repo = java-1.8.0-openjdk-dev ]; then
  local job=pull-ojdk8u-dev-static
elif [ $repo = java-1.8.0-openjdk-aarch64 ]; then
  local job=pull-ojdk8u-aarch64-static
elif [ $repo = java-1.8.0-openjdk-aarch64-shenandoah ]; then
  local job=pull-ojdk8u-aarch64-shenandoah-static
elif [ $repo = java-1.8.0-openjdk-shenandoah ]; then
  local job=pull-ojdk8u-shenandoah-static
elif [ $repo = java-9-openjdk ]; then
  local job=pull-ojdk9-static
elif [ $repo = java-9-openjdk-dev ]; then
  local job=pull-ojdk9-dev-static
elif [ $repo = java-9-openjdk-shenandoah ]; then
  local job=pull-ojdk9-shenandoah-static
elif [ $repo = java-1.7.0-openjdk-forest-26 ]; then
  local job=pull-ojdk7-forest-26-static
elif [ $repo = java-9-openjdk-updates ]; then
  local job=pull-ojdk9-updates-static
elif [ $repo = java-10-openjdk ]; then
  local job=pull-ojdk10-static
elif [ $repo = java-X-openjdk ]; then
  local job=pull-ojdkX-static
else
  echo "Unknow repo/job mapping - $repo!!!"
  return 1
fi
  set -x
  curlMaster $job
  set +x
}

set -e
# reason:
# high trafic, pull once(twice?) per week, friday evening?
# pull-ojdk8u-dev-static					
# pull-ojdk8u-static
# pull-ojdk9-dev-static							
# pull-ojdk9-static						
# low trafic, pull every (second?)day
# pull-ojdk8u-aarch64-shenandoah-static
# pull-ojdk8u-aarch64-static				
# pull-ojdk9-shenandoah-static	
# pull-ojdk7-forest-static
# pull-ojdk7u-static

# this script iterate through the arguments (repos) and hgIncomming them. If changes found, this repo is marekd, and last time is started from NEXT repo. So each repo should have square chances

readonly INIT_DIR=$PWD
pointer=0
#small cheat to skip complicated (in bash) rewind in array
for x in ${@} ${@} ; do
  REPOS_TO_WATCH[$pointer]=$x
  let pointer=$pointer+1
done
# always not-odd
let REPOS_COUNT=$pointer/2


. $SCRIPT_DIR/../custom_run_wrappers/parts/initMachines.sh

# locate and process saved "last changed record"
tmpfile=`mktemp`
rm $tmpfile
cfgName=`echo "${REPOS_TO_WATCH[@]}" | sed "s;\s\+;_;g"`
#crap, this filename may grow longer then 255 chars, so we have to compress it
if [ ${#cfgName} -gt 200 ] ; then
  cfgName=`echo "$cfgName" | sed "s;\.\+;;g" | sed "s;-\+;;g" | sed "s;java;j;g" | sed "s;openjdk;ojdk;g" `
fi
if [ ${#cfgName} -gt 200 ] ; then
  cfgName=`echo $cfgName | md5sum  | sed "s/ .*//"`
fi
CONFIG=`dirname $tmpfile`"/"$cfgName".cfg"
LAST_DONE=""
pointer=0
if [ -f $CONFIG ] ; then
  LAST_DONE=`cat $CONFIG`
  for repo in "${REPOS_TO_WATCH[@]}" ; do
    if [ $repo == $LAST_DONE ]; then
      echo "$repo matched the last tempted ($pointer)"
      let pointer=$pointer+1
      break
    fi
    echo "$repo moved to end of queue"
    let pointer=$pointer+1
  done
else
  echo "no $CONFIG found."
fi
#we have to end at REPOS_COUNT. No later. If this hapened, the repo in cfg file no longer exists
if [ $pointer -gt $REPOS_COUNT ]; then
  echo "$LAST_DONE not found. Reseting"
  rm $CONFIG
  LAST_DONE=""
  pointer=0
fi
echo "Should start at $pointer - ${REPOS_TO_WATCH[$pointer]}"

let endOfLoop=$pointer+$REPOS_COUNT

for ((x=pointer; x<endOfLoop; x++)) ; do
  repo=${REPOS_TO_WATCH[$x]} 
  export DONT_PULL=99
  echo "checking $repo"
  tempting=0
  sh $SCRIPT_DIR/tempt-ojdk-repo.sh $repo > $repo.out  2>$repo.err ||   tempting=$? ;
  mv hgIncoming.log hgIncoming.log-$repo
  if [ $tempting -eq 99 ] ; then
    echo "Changed! $repo"
    echo $repo > $CONFIG
    executeJenkinsPullJobFor $repo
    exit
  elif [ $tempting -eq 0 ] ; then
    echo "NoChange $repo"
  else
    echo "Error!!! $repo"
  fi
done
