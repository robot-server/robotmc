#!/bin/bash

work_dir=$(pwd)
source .env
echo ${MINECRAFT_DIR}/${SERVER_JAR}

chmod +x ./backup.sh
while [ -f ${MINECRAFT_DIR}/${SERVER_JAR} ]
do
	cd ${MINECRAFT_DIR}
	java -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE} -jar ${SERVER_JAR} ${OPTION}
	cd ${work_dir}
	./backup.sh
done
