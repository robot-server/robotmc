#!/bin/bash

work_dir=$(pwd)
minecraft_dir=~/minecraft
server_jar=server.jar
option=nogui

jvm_heap_size=1024M

while [ -f ${minecraft_dir}/${server_jar} ]
do
	cd ${minecraft_dir}
	java -Xms${jvm_heap_size} -Xmx${jvm_heap_size} -jar ${server_jar} ${option}
	cd ${work_dir}
	sh backup.sh
done
