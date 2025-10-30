#!/bin/bash

level_name=world
minecraft_dir=../minecraft
backup_dir=../backup

timestamp=$(date +%Y-%m-%d_%H-%M-%S)
cd ${minecraft_dir}
if [ ! -d ${backup_dir} ]; then
	mkdir ${backup_dir}
fi
tar cfvz ${backup_dir}/${level_name}_${timestamp}.tgz ${level_name} ${level_name}_*
