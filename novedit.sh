#!/bin/sh


self="${0#./}"
base="${self%/*}"
current=$(pwd)

param=$(readlink -f "$1")

if [ "$base" = "$self" ]
then
  path=$current
else
  path=$current/$base
fi 

cd $path/lib
#Quick hack : second parameter for a '--test' option
ruby ../bin/novedit $param $2
cd -
