#!/bin/bash

eon() {
  TIME_START=$SECONDS
  echo -n "$( date -u +'%Y%m%d-%H%M%S' ) "
  echo -n "$@"
  echo -n '... '
  if [[ -n $LINE_BUFFERED ]] ; then
    echo ''
  fi
}

edone() {
  if [[ -n $LINE_BUFFERED ]] ; then
    echo -n "$( date -u +'%Y%m%d-%H%M%S' ) "
  fi
  echo "done in $( date -u -d @$(( $SECONDS - $TIME_START )) +'%H:%M:%S' )."
}

efail() {
  if [[ -n $LINE_BUFFERED ]] ; then
    echo -n "$( date -u +'%Y%m%d-%H%M%S' ) "
  fi
  echo "failed in $( date -u -d @$(( $SECONDS - $TIME_START )) +'%H:%M:%S' )."
}

timeout() {
  bash "$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/timeout.sh" "$@"
}

mkTempDir() {
  if [[ -d '/mnt/ramdisk' ]] ; then
    mktemp -d -p '/mnt/ramdisk'
  else
    mktemp -d
  fi
}

mkTempFile() {
  if [[ -d '/mnt/ramdisk' ]] ; then
    mktemp -p '/mnt/ramdisk'
  else
    mktemp
  fi
}

fileModTimestamp() {
  local filePath="$1"
  local fileEpoch="$( stat -c '%Y' "$filePath" )"
  local fileTimestamp="$( date -u +'%Y%m%d-%H%M%S' -d @$fileEpoch )"
  echo "$fileTimestamp"
}

## When only one RPM is provided, find neighbouring RPMs, unpack
## them and move the contents into target folder.
## Accepts 2 positional parameters:
##  * path to main RPM
##  * target dir
findAndUnpackRpms() {

  local rpm_path="$1"
  local target_path="$2"

  eon 'Determining names of RPMs'
  local prefix_length=19
  local rpm_dir="$( dirname "$rpm_path" )"
  local rpm_main="$( basename "$rpm_path" )"
  local rpm_headless="${rpm_main:0:prefix_length}headless-${rpm_main:19}"
  local rpm_devel="${rpm_main:0:prefix_length}devel-${rpm_main:19}"
  edone

  eon 'Unpacking RPMs'
  local rpm_tmp="$( mkTempDir )"
  for r in "$rpm_headless" "$rpm_main" "$rpm_devel"
  do
    if [[ -f "$rpm_dir/$r" ]] ; then
      ( cd "$rpm_tmp" && rpm2cpio "$rpm_dir/$r" | cpio -id --no-absolute-filenames --quiet -u )
    fi
  done
  edone

  eon 'Copying unpacked content to target dir'
  mkdir -p "$target_path"
  (
    cd "$rpm_tmp/usr/lib/jvm"
    for d in *
    do
      if [[ -d "$d" && -x "$rpm_tmp/usr/lib/jvm/$d/bin/java" ]] ; then
        cd "$rpm_tmp/usr/lib/jvm/$d"
        mv -t "$target_path" *
        break
      fi
    done
  )
  edone

  eon 'Checking cacerts symlink'
  if [[ -h "$target_path/jre/lib/security/cacerts" ]] ; then
    ( cd "$target_path/jre/lib/security" && rm -f 'cacerts' && ln -s '/etc/pki/java/cacerts' "$target_path/jre/lib/security/cacerts" )
  fi
  edone

  eon 'Cleaning up the unpacked RPM'
  ( rm -rf "$rpm_tmp" )
  edone
}

getIpFromHostname() {
  local HOSTNAME=$1

  if isLinux; then
    echo $( ping -c 1 $HOSTNAME | awk -F'[()]' '/PING/{print $2}' )
  elif isWindows; then
    echo $( ping -4 $HOSTNAME count 1 | awk -F'[()]' '/PING/{print $2}' )
  fi
}

isPingable() {
  if isLinux; then
    ping -c 1 $1 1> /dev/null 2> /dev/null
  elif isWindows; then
    ping $1 count 1 1> /dev/null 2> /dev/null
  else
    return 1
  fi
}

isLinux() {
  if [ $( uname ) == "Linux" ]; then
    return 0
  else
    return 1
  fi
}

isWindows() {
  if [[ $( uname ) == *"NT"* ]]; then
    return 0
  else
    return 1
  fi
}

getJdkMajor() (
    # jdk we are interested in
    local targetJdk="${1}"

    cleanup() {
        [ -z "${rtjar}" ] || rm -rf "${rtjar}"
        [ -z "${classes}" ] || rm -rf "${classes}"
        [ -z "${rpmdir}" ] || rm -rf "${rpmdir}"
    }
    local rtjar=''
    local classes=''
    local rpmdir=''
    local detectedMajor=''

    trap cleanup EXIT

    local rtjar="$( mkTempFile )"
    if [[ -d $targetJdk ]] ; then
        if [[ -e "$targetJdk/jre/lib/rt.jar" ]] ; then
            cat "$targetJdk/jre/lib/rt.jar" >$rtjar
        elif [[ -e "$targetJdk/bin/jshell" ]] \
        || [[ -e "$targetJdk/bin/jshell.exe" ]] ; then
            local jshellScript="$( mkTempFile )"
            if isWindows; then
              jshellScript=$( cygpath -pm $jshellScript )
            fi
            printf "System.out.print(Runtime.version().major())\n/exit" > ${jshellScript}
            detectedMajor=$( $targetJdk/bin/jshell ${jshellScript} 2> /dev/null )
            rm ${jshellScript}
        else
            echo "No decission point in $targetJdk directory" >&2
        fi
    elif [[ $targetJdk == *.tar.gz ]] ; then
        tar -xOzf "$targetJdk" */jre/lib/rt.jar >$rtjar
    elif [[ $targetJdk == *.tar.xz ]] ; then
        tar -xOJf "$targetJdk" */jre/lib/rt.jar >$rtjar
    elif [[ $targetJdk == *.rpm ]] ; then
        rpmdir="$( mkTempDir )"
        findAndUnpackRpms "$targetJdk" "$rpmdir" 1>/dev/null
        cat "$rpmdir/jre/lib/rt.jar" >$rtjar
    fi
    if [ -z "${detectedMajor}" ] ; then
        classes="$( mkTempFile )"
        if ( unzip -l $rtjar 2>/dev/null | awk '{ print $4 }' | grep '^java/' ) >$classes
        then
            if ( grep -q 'java/nio/file/FileTreeIterator.class' "$classes" )
            then
                detectedMajor='8'
            elif ( grep -q 'java/nio/file/Path.class' "$classes" )
            then
                detectedMajor='7'
            elif ( grep -q 'java/lang/System.class' "$classes" )
            then
                detectedMajor='6'
            fi
        else
            echo "Failed to list rt.jar from JDK: '$targetJdk'" >&2
            return 1
        fi
    fi

    if ! printf "%s" "${detectedMajor}" | grep -q '[0-9]\+' ; then
        echo "Detected version does not have valid format: ${detectedMajor}"    >&2
        return 1
    fi
    printf "%s" "${detectedMajor}"
)

getJdkMajorTck() {
    local targetJdk="${1}"

    local detectedMajor="$( getJdkMajor "${targetJdk}" )" || return 1
    case "${detectedMajor}" in
        6)
            printf '%s' '6b'
            ;;
        8)
            printf '%s' '8b'
            ;;
        *)
            printf '%s' "${detectedMajor}"
            ;;
    esac
}
