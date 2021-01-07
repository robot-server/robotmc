#!/bin/bash

minecraft_dir=~/minecraft

if [ $# -ne 2 ]; then
    echo Usage: recovery.sh backup level_name
    exit 1
fi

backup=$1
level_name=$2

echo ${backup} → ${level_name}
rm -r ${minecraft_dir}/${level_name} ${minecraft_dir}/${level_name}_*
tar xfvz ${backup} -C ${minecraft_dir}
