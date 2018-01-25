#!/bin/bash
log=$1
e1="error C2819: type 'JNIEnv_' does not have an overloaded member 'operator ->'"
e2="error C2232: '->JNIEnv_::ExceptionCheck' : left operand has 'struct' type, use '.'"
w=`grep $log  -e "$e1" -e "$e2" | wc -l`
if [ $w -gt 0 ] ; then
  echo "<h3> $e1 + $e2</h3>"
  echo "<div>known failure appeared $w times: This was reported HERE and have fix of THIS. LAst sucessfull bu8ld without this was jdk7u141.b02-0.upstr​eam Aug 9, 2017 6:34 AM</div>"
fi

e3="[javac] javac: invalid target release: 7"
ee3=`echo $e3 | sed  's;\[;\\\\[;' | sed  's;\];\\\\];' `
w=$(grep $log  -e "$ee3" | wc -l)
if [ $w -gt 0 ] ; then
  echo "<h3> $e3</h3>"
  echo "<div>known failure appeared $w times: This is known filure of icedtea</div>"
fi

exit 0
