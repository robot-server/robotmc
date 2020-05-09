#!/bin/bash

server_jar=server.jar
option=nogui

jvm_heap_size=1024M

while :
do
	java -Xms${jvm_heap_size} -Xmx${jvm_heap_size} -jar ${server_jar} ${option}
done
