set -x
set -e
set -o pipefail

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

pgm=`mktemp -d`

# its expected to run on hydra/odin
JAVAC=/opt/jdk/bin/javac
JAVA=/opt/jdk/bin/java
if [ ! -f $JAVAC ] ; then
  JAVAC=javac
fi
if [ ! -f $JAVA ] ; then
  JAVA=java
fi

$JAVAC -d $pgm  $SCRIPT_DIR/*.java
$JAVA -cp $pgm  CheckBugs ${@}

rm -rf $pgm

