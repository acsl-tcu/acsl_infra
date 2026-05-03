#! /usr/bin/bash

if [ $# -eq 2 ]; then
  target=$2
else
  target="build"
fi

if [ ${HOSTNAME:0:1} == "D" ]; then
  ssh -o StrictHostKeyChecking=no $HOST_USER@172.17.0.1 "docker tag kasekiguchi/acsl-common:$1 kasekiguchi/acsl-common:$target"
else
  #docker commit kasekiguchi/acsl-common:$1 kasekiguchi/acsl-common:$target
  docker tag kasekiguchi/acsl-common:$1 kasekiguchi/acsl-common:$target
fi
