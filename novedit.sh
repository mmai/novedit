#!/bin/sh


self="${0#./}"
base="${self%/*}"
current=$(pwd)

if [ "$base" = "$self" ]
then
  path=$current
else
  path=$current/$base
fi 

cd $path/lib
ruby ../bin/novedit $current/$1
cd -
