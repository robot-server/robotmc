#!/bin/bash

minecraft_dir=~/minecraft

backup=$1
level_name=$2

echo ${backup} → ${level_name}
rm -r ${minecraft_dir}/${level_name} ${minecraft_dir}/${level_name}_*
tar xfvz ${backup} -C ${minecraft_dir}
