#!/bin/bash
if [ "x$COLOUR" == "x" ] ; then
  colour=red
else
  colour=$COLOUR
fi
if [ "x$AFTER" == "x" ] ; then
  after=5
else
  after=$AFTER
fi
if [ "x$BEFORE" == "x" ] ; then
  before=5
else
  before=$BEFORE
fi
if [ "x$TAIL" == "x" ] ; then
  tailLines=10
else
  tailLines=$TAIL
fi
if [ "x$WORDS" == "x" ] ; then
  caseInsensitiveKeywords="fail failure error failed fails failures errors"
else
  caseInsensitiveKeywords="$WORDS"
fi
if [ "x$FINAL_FILE" == "x" ] ; then
  finalFile=final.html
else
  finalFile=$FINAL_FILE
fi

grepexp="grep  -A $after -B $before -i "
for exp in $caseInsensitiveKeywords ; do
 grepexp="$grepexp -e [^a-zA-Z]$exp[^a-zA-Z]"
done

setPlaintextLogName() {
 llog=`basename $log`
 echo $llog-grepped-$finalFile.log | sed "s/.html./.plain./" ;
}

for log in ${@} ; do
  greppedPlaintext=`setPlaintextLogName`
  cat $log | $grepexp >  $greppedPlaintext
  echo "--" >>  $greppedPlaintext
  tail $log -n $tailLines >>  $greppedPlaintext
done

for log in ${@} ; do
  llog=`basename $log`
  greppedPlaintext=`setPlaintextLogName`
  cp $greppedPlaintext $llog.html
  for exp in $caseInsensitiveKeywords ; do
    # warning, there is duplicated code in output below
    sed "s;[^a-zA-Z]$exp[^a-zA-Z];<b><font color=\"$colour\">&</font></b>;gI" -i  $llog.html
  done
  sed "s;^--$;<hr/>;gI"  -i  $llog.html
done

#3*33 percent somehow do not fit to 100 percent
WwW=95
let width=$WwW/$#

echo "<html>" > $finalFile
echo "<head>" >> $finalFile
echo "  <meta charset=\"UTF-8\">" >> $finalFile
echo "  <style>" >> $finalFile
echo "  .wrap {" >> $finalFile
echo "      border-width:1px; " >> $finalFile
echo "      border-style: solid;" >> $finalFile
echo "      float: left;" >> $finalFile
echo "      display: inline;" >> $finalFile
echo "      overflow: scroll;" >> $finalFile
echo "      white-space: nowrap;" >> $finalFile
echo "      width: $width%;" >> $finalFile
echo "  }" >> $finalFile
echo "  .buttonWrap {" >> $finalFile
echo "      border-width:1px; " >> $finalFile
echo "      border-style: solid;" >> $finalFile
echo "      float: left;" >> $finalFile
echo "      display: inline;" >> $finalFile
echo "  }" >> $finalFile
echo "  .resetWrap {" >> $finalFile
echo "      clear: left;" >> $finalFile
echo "      display: block;" >> $finalFile
echo "  }" >> $finalFile
echo "</style>" >> $finalFile
echo "  <script type='application/javascript'>" >> $finalFile
echo "    function buttonClick(idx){" >> $finalFile
echo "      var e = document.getElementById(idx);" >> $finalFile
echo "  	if (e.style.display=='none') {" >> $finalFile
echo "  		e.style.display='inline'" >> $finalFile
echo "  	} else {" >> $finalFile
echo "  		e.style.display='none'" >> $finalFile
echo "  	}" >> $finalFile
echo "   var x = document.getElementsByClassName('wrap');" >> $finalFile
echo "   var i=0;" >> $finalFile
echo "   var w=100" >> $finalFile
echo "   for (y = 0; y < x.length; y++) {" >> $finalFile
echo "     if (x[y].style.display!='none') {" >> $finalFile
echo "       i++" >> $finalFile
echo "      }" >> $finalFile
echo "    }" >> $finalFile
echo "     if (i>0) {" >> $finalFile
echo "       w=$WwW/i" >> $finalFile
echo "       for (y = 0; y < x.length; y++) {" >> $finalFile
echo "         if (x[y].style.width=''+w+'%') {" >> $finalFile
echo "           i++" >> $finalFile
echo "          }" >> $finalFile
echo "        }" >> $finalFile
echo "      }" >> $finalFile
echo "   }" >> $finalFile
echo "  </script>" >> $finalFile
echo "</head>" >> $finalFile
echo "<body>" >> $finalFile
for log in ${@} ; do
  greppedPlaintext=`setPlaintextLogName`
  if [[ $log == *all* ]] ; then
   # comes from caller, sorry
   echo `sh $SCRIPT_DIR/knownFailures.sh $greppedPlaintext` >> $finalFile
  fi
  echo "<div class=\"buttonWrap\">" >> $finalFile
  echo "<button onclick=\"buttonClick('$log')\" id=\"$log-button\"> `basename $log` </button> " >> $finalFile
  echo " <a href='$log'> $log </a> <br/> " >> $finalFile
  echo " <a href='$greppedPlaintext'> $greppedPlaintext </a> " >> $finalFile
  echo "</div>" >> $finalFile
done
echo "<div class=\"resetWrap\"></div>" >> $finalFile
for log in ${@} ; do
  llog=`basename $log`
  echo "<div class=\"wrap\" id=\"$log\">" >> $finalFile
    echo "<h3>$log</h3>" >> $finalFile
    echo "<pre>" >> $finalFile
      cat $llog.html >> $finalFile
    echo "</pre>" >> $finalFile
  echo "</div>" >> $finalFile
  rm  $llog.html
done

echo "<div class=\"resetWrap\"></div>" >> $finalFile
echo "<hr/>" >> $finalFile
echo "$grepexp" >> $finalFile
echo "<hr/>" >> $finalFile
echo "tail -n $tailLines" >> $finalFile
echo "<hr/>" >> $finalFile
  for exp in $caseInsensitiveKeywords ; do
    # this is duplicated code in output below
    echo "sed \"s;[^a-zA-Z]$exp[^a-zA-Z];&lt;b&gt;&lt;font color=\"$colour\"&gt;&amp;&lt;/font&gt;&lt;/b&gt;;gI\" -i <br/>"  >> $finalFile
  done
echo "<hr/>" >> $finalFile

echo "</body></html>" >> $finalFile
