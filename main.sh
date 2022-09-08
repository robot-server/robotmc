#!/bin/bash

minecraft_dir=~/minecraft
server_jar=server.jar

while [ -f ${minecraft_dir}/${server_jar} ]
do
	docker-compose up
	sh backup.sh
done
