#!/bin/bash

CNDIR="/srv/cndata"

if [ "$1" == "CLEAR" ];
then
	for d in ${CNDIR}/state/*
	do
		if [ -d $d ];
		then
			rm -fr ${d}/*
		else
			echo "Skipping $d -- not a directory"
		fi
	done
	
	exit 0
fi

if [ "$1" == "CREATE" ];
then
	if [ "$2" == "" ];
	then
		echo Need second argument: hostdb file
		echo Use dhcpconf2db.sh to generate one if needed.
		exit 1
	fi

	OLDIFS=$IFS
	IFS=$'\n'

	for line in `cat $2`
	do
		hostname=`echo $line | awk '{print $3}'`
		echo $hostname
		mkdir -p ${CNDIR}/state/${hostname}.geohpcc.local
	done
	IFS=$OLDIFS

	exit 0
fi

echo Need command: CLEAR or CREATE
