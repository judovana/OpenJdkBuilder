function printXmlTest { # classname testname, time, file, jenkins view_dir
  classname="$1"
  testname="$2"
  time="$3"
  logFile="$4"
  viewFileStub="$5"
  echo -n "    <testcase classname=\"$classname\" name=\"$testname\" time=\"$time\""
  if [ -z "$logFile" ]; then
    echo "/>"
  else
    echo ">"
    echo "      <failure message=\"see: ../artifact/$viewFileStub\" type=\"non zero sub-shell return code\">"
    echo -n "        <![CDATA["
    echo "----head -n 10----"
    head -n 10 $logFile
    echo "-------------- grep -n -i -e fail -e error -B 5 -A 5--------------"
    grep -n -i -e fail -e error -B 5 -A 5 $logFile || true
    echo "-------------- tail -n 10 --------------"
    tail -n 10 $logFile
    echo "]]>
      </failure>" 
    echo "    </testcase>"
  fi
}

function printXmlHeader { # passed failed tests
  passed="$1"
  failed="$2"
  tests="$3"
  classsuite="$4"
  hostname=$(hostname)
  datetime=$(date +%Y-%m-%dT%H:%M:%S)
  echo "<?xml version=\"1.0\"?>"
  echo "<testsuites>" 
  echo "  <testsuite errors=\"0\" failures=\"$failed\" passed=\"$passed\" tests=\"$tests\" skipped=\"0\" name=\"$classsuite\" hostname=\"$hostname\" time=\"0.1\" timestamp=\"$datetime\">" #2018-03-24T22:19:45
}

function printXmlFooter { 
  echo "    <system-out></system-out>"
  echo "    <system-err></system-err>"
  echo "  </testsuite>"
  echo "</testsuites>"
}
