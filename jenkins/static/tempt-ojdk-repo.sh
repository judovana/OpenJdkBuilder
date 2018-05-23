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


if [ $# -ne 1 ] ; then
  echo 'expected exactly one command line argument with REPO name' >&2
  exit 1
fi

INIT_DIR=$PWD

readonly REPO="$1"

# github only!!
#. $SCRIPT_DIR/../custom_run_wrappers/parts/initMachines.sh

readonly TARGET_DIR=$UPSTREAM_REPOS_PATH/$REPO

if [ -z "${SRC_VARIANTS:-}" ] ; then
	SRC_VARIANTS=".upstream .upstream.fastdebug"
fi

# the "fake koji database" should have in top level exactly products (java-1.8.0-openjdk, java-9-openjdk ..)
# however, more repos can end in one product (eg both java-1.8.0-openjdk and java-1.8.0-openjdk-dev will end in java-1.8.0-openjdk)
# so the suffix of repo is cut, and used inside release (with dashes repalced by dots, before os and arch)
dashes=`echo "$REPO" | grep -o -e "-" | wc -l`
if [ $dashes  -lt 2 ] ; then
  echo "Strange repo! 2 and more dashes expected in name!"
fi
if [ $dashes  -gt 2 ] ; then
  # replace first three - by delimiter, then remove all  upto it. Thats suffix
  DELIMITER=XXXX
  SUFFIX=`echo $REPO | sed "s/-/$DELIMITER/"  | sed "s/-/$DELIMITER/"  | sed "s/-/DELIMITER/" | sed "s/.*DELIMITER//"`
  PREFIX=`echo $REPO | sed "s/-$SUFFIX//"`
  #clean suffix out of dashes
  SUFFIX=.`echo $SUFFIX | sed "s/-/./g"`
else
  PREFIX=$REPO
  SUFFIX=""
fi

if [ ! -d $TARGET_DIR ] ; then
  echo "$TARGET_DIR repo for $REPO do not exists"
  exit 1
fi

rm -rf *.tarxz
rm -rf *.log
rm -rf *.html

fileList1=`mktemp`
ls | sort > $fileList1 


subrepos=`find $TARGET_DIR/ | grep "/.hg$"`
subrepoCount=`find $TARGET_DIR/ | grep "/.hg$" | wc -l`

# keys of this map are subrepos names
declare -A OLD_HEADS
declare -A NEW_HEADS
readonly incomingLog=$TARGET_DIR/hgIncoming.log
readonly OLD_HEADS_FILE=$INIT_DIR/OLD_HEADS
readonly NEW_HEADS_FILE=$INIT_DIR/NEW_HEADS
readonly PATCH_FILE=$INIT_DIR/patch.patch
rm -f $OLD_HEADS_FILE
rm -f $NEW_HEADS_FILE
rm -f $PATCH_FILE

noChnage=0
#logs are in TARGET, as we wont them in tarball
echo "see `basename $incomingLog` (from $incomingLog)"
echo "hg incoming in $REPO, `date`, `hostname`, $TARGET_DIR" > $incomingLog
for subrepoHg in $subrepos ; do 
  subrepo=`dirname $subrepoHg`
  repoXname=`basename $subrepo`
  echo "checking $REPO/`basename $subrepo`"
  pushd $subrepo >> $incomingLog
  hg incoming  --template $SCRIPT_DIR/defaultAndDescription.template  >> $incomingLog
  change=$?
  OLD_HEADS[$repoXname]=`hg log | head -n 1 | sed "s/.*://"`
  echo $repoXname `hg log | head -n 1 ` >> $OLD_HEADS_FILE
  let noChnage=$noChnage+$change
  if [ $change -ne 0 ] ; then
    echo "no change" | tee -a $incomingLog
   else
    echo "changed!" | tee -a $incomingLog
    echo "files affected:" >> $incomingLog
    a=`hg incoming --template {files}`
    for x in $a ; do  echo $x >> $incomingLog ; done
  fi
  popd >> $incomingLog
done

let changedRepos=$subrepoCount-$noChnage

if [ $changedRepos -lt 0 ] ; then
  echo "Negative number of changes, that mostly means network outage."
  echo "Reseting to no chnage."
  let changedRepos=0
  let noChnage=$subrepoCount
fi

echo "no change in $noChnage repos of $subrepoCount" | tee -a $incomingLog
echo "changed $changedRepos repos of $subrepoCount" | tee -a $incomingLog

echo "In "$subrepos
if [ $changedRepos -eq 0 ] ; then
  echo "xxx NO CHANGE DETECTED xxx" | tee -a $incomingLog
  if [ ! "x$NO_CHANGE_RETURN" == "x" ] ; then
    if [ "$NO_CHANGE_RETURN" -gt "-1" ] ; then
      mv $incomingLog .
      exit $NO_CHANGE_RETURN
    else
    echo "NO_CHANGE_RETURN is '$NO_CHANGE_RETURN'. Any negative is forcing pull."     
    fi
  else
    # with NO_CHANGE_RETURN thes returns peacefully
    mv $incomingLog .
    exit 0
  fi
else
echo "### CHANGES DETECTED ###" | tee -a $incomingLog
fi 

if [ ! "x$DONT_PULL" = "x" ] ; then
  echo "Exiting on DONT_PULL=$DONT_PULL set" | tee -a $incomingLog
  mv $incomingLog .
  exit $DONT_PULL
fi

echo "!!! pulling !!!"


pullLog=$TARGET_DIR/hgpull.log
hgLogs="$incomingLog $pullLog"
echo "see `basename $pullLog` (from $pullLog)"
echo "hg pull+update in $REPO, `date`, `hostname`, $TARGET_DIR" > $pullLog
for subrepoHg in $subrepos ; do 
  subrepo=`dirname $subrepoHg`
  repoXname=`basename $subrepo`
  pushd $subrepo >> $pullLog
  echo "pulling at $REPO/$repoXname"
  if ! hg pull >> $pullLog  ; then
   echo "Some error during pooling" |  tee -a $pullLog
  fi
  echo "updating at $REPO/$repoXname"
  if ! hg update >> $pullLog ; then
   echo "Some error during updating" |  tee -a $pullLog
  fi
  updateLog=$TARGET_DIR/$repoXname-hg.log
  hg log --template $SCRIPT_DIR/defaultAndDescription.template > $updateLog
  hgLogs="$hgLogs $updateLog"
  NEW_HEADS[$repoXname]=`hg log | head -n 1 | sed "s/.*://"`
  echo $repoXname `hg log | head -n 1 ` >> $NEW_HEADS_FILE
# generating megapatch
  echo "# $subrepo hg diff -r ${OLD_HEADS[$repoXname]} -r ${NEW_HEADS[$repoXname]}" >> $PATCH_FILE
  hg diff -r ${OLD_HEADS[$repoXname]} -r ${NEW_HEADS[$repoXname]} >> $PATCH_FILE
  popd >> $pullLog
done

cat $pullLog |  grep "other heads for branch"
if [ $? -eq 0 ] ; then
  echo "OTHER HEAD DETECETD! aborting!"  |  tee -a $pullLog
  exit 100
fi

lastTag=""

# trying the javas implementation of search for paths, on selected repos only
if [ $REPO = "java-1.7.0-openjdk" -o $REPO = "java-1.7.0-openjdk-forest" -o $REPO = "java-1.7.0-openjdk-forest-26" -o $REPO = "java-1.8.0-openjdk" -o $REPO = "java-1.8.0-openjdk-aarch64" -o $REPO = "java-1.8.0-openjdk-aarch64-shenandoah" -o $REPO = "java-1.8.0-openjdk-dev" -o $REPO = "java-9-openjdk" -o $REPO = "java-9-openjdk-dev" -o $REPO = "java-9-openjdk-shenandoah" ] ; then
   javak=`mktemp -d`
   /opt/jdk/bin/javac -d $javak  $SCRIPT_DIR/../../hgRepoTagsSearch/MercurialTracker.java
   if [ ! $REPO = "java-9-openjdk-shenandoah" ] ; then
     /opt/jdk/bin/java -cp $javak MercurialTracker $TARGET_DIR -log=$INIT_DIR
   fi
   lastTag=`/opt/jdk/bin/java -cp $javak MercurialTracker -tipTagsOnly $TARGET_DIR -log=$INIT_DIR`
   rm -rf $javak
fi

pushd $TARGET_DIR
  # when new head come toplay, this may go wrong, see cpu's aarch64 pulls 11 and 12
  #lastTag=`hg log -r "." --template "{latesttag}\n"`
  lastTagHgCandidate=`hg log  --template "{latesttag}\n" | head -n 1`
popd


# we prefere tag which above java analys gave us, but it is enabled only for some (most of, but not all) repos
if [ "$lastTag" == "" ] ; then
  lastTag="$lastTagHgCandidate"
  echo "mercurial claims last tag is $lastTag and we will use it"
else
  echo "deep java analyse  claims last tag is $lastTag (mercurial claimed it as $lastTagHgCandidate but we dont trust it)"
fi 

if [ -z "${lastTag:-}" ] || [ "${lastTag:-}" = "null" ] || [ "${DISABLE_TAGS:-0}" -eq 1 ] ; then
	# repo has no tags
	lastTag="no.tags"
	disableTags=1
else
	disableTags=0
fi

#jdk9 introduced + instead of b in build...
lastTagNoDash=`echo "$lastTag" | sed s/-/\\./g  | sed s/+/./g | sed s/[[:space:]]/_/g`

# now cunt changes in repo since last tag
totalChanges=0
for subrepoHg in $subrepos ; do 
  subrepo=`dirname $subrepoHg`
  pushd $subrepo
  if [ "${disableTags}" -eq 0 ] ; then
    changes=`hg log | grep summary | grep -B 10000000000 "$lastTag" | wc -l`
  else
    changes=`hg log | grep summary | wc -l`
  fi
  # remove tag itself
  let changes=$changes-1
  let totalChanges=$totalChanges+$changes
  echo "$changes changes since $lastTag"
  popd
done
echo "$totalChanges total changes since $lastTag"

#extending SUFFIX by custom part
SUFFIX="${SUFFIX}${CUSTOMSUFFIX}"

archivePaths=""
for srcVariant  in ${SRC_VARIANTS} ; do
	# N-V-R.A."rpm"
	# name, version... release ususally consists from number.os, arch is src
	# the dot in tar.xz is not allowed, as all tools are expecting ..release.arch.suffix. So any dot in suffix itself wil crash them
	# removing all possible duplicated dashes
	archive="$( printf '%s' "$PREFIX-$lastTagNoDash-$totalChanges$SUFFIX${srcVariant}.src.tarxz" | sed "s/--\+/-/g" )"
	archivePath="$INIT_DIR/${archive}"
	# paths are space separated ... :/
	archivePaths="$( printf '%s' "${archivePaths} ${archivePath}" )"
done

firstArchivePath=""
for archivePath in ${archivePaths} ; do
	if [ ! -f "$archivePath" -o "x${FORCE_OVERRIDE:-}" == "xtrue" ] ; then
		pushd `dirname $TARGET_DIR`
			if [ -z "${firstArchivePath:-}" ] ; then
				# with .hg is 350mb, without is 55mb ...
				# that is reasonable saving of both speed and space
				set -x
				tar  --transform="flags=r;s|$REPO|openjdk|" --exclude-vcs -cJf $archivePath $REPO
				set +x
				firstArchivePath="${archivePath}"
				DEFAULT_RETURN=$?
			else
				set -x
				cp "${firstArchivePath}" "${archivePath}"
				set +x
			fi
		popd
	else
	  echo "not archiving, as ${archivePath} exists,  but reusing. FORCE_OVERRIDE is '${FORCE_OVERRIDE:-}'. 'true' would force the overwrite "
	fi
done

# backup  logs
for log in $hgLogs ; do
  cp -v $log .
done

rm -rf logsAnalyse.log *.html
sh ~/vm-shared/TckScripts/CheckBugs/analyseHgIncomming.sh  > idsInChangeset.html  2>> logsAnalyse.log
sh ~/vm-shared/TckScripts/CheckBugs/analyseHgLogs.sh  > idsStatuses.html  2>> logsAnalyse.log

fileList2=`mktemp`
ls | sort > $fileList2
diff -Nau $fileList1 $fileList2

for archivePath in ${archivePaths} ; do
  #scp result
  #values are known from init machines

  set -x
# DESTINATION is from initMachines.sh, and is user@machine, feel free change by ALTERNATIVE_DESTINATION
# if you dont specify user, default user from initMachines is used
  if [ ! "x$ALTERNATIVE_DESTINATION" = "x" ] ; then
    DESTINATION=$ALTERNATIVE_DESTINATION
    if [[ ! $DESTINATION = *@* ]] ; then 
      DESTINATION=$master_user@$DESTINATION
    fi
  fi
  if [ ! "x$NO_UPLOAD" == "xTRUE"  ] ; then
    scp -o StrictHostKeyChecking=no -P 9822 $archivePath $DESTINATION:
    scp -o StrictHostKeyChecking=no -P 9822 logsAnalyse.log *.html $OLD_HEADS_FILE $NEW_HEADS_FILE $PATCH_FILE $hgLogs $DESTINATION:$archivePath/logs
  fi

CUSTOM_ARCHES_FILE=$TARGET_DIR/arches-expected
  if [ -e $CUSTOM_ARCHES_FILE ] ; then
    if [ ! "x$NO_UPLOAD" == "xTRUE"  ] ; then
      scp -o StrictHostKeyChecking=no -P 9822 $CUSTOM_ARCHES_FILE $DESTINATION:$archivePath/data
    fi
  fi
  set +x
done

# remove uploaded and archived logs
for log in $hgLogs ; do
  rm -fv $log
done

if [ ! "x$CHANGE_RETURN" == "x" ] ; then
  exit $CHANGE_RETURN
else
  exit $DEFAULT_RETURN
fi
