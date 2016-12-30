#!/bin/bash

CNDIR="/srv/cndata"
HOSTHOSTS="/etc/hosts"
CNHOSTS="${CNDIR}/cnimage/etc/hosts"
IDLINE="# Automatically generated"
DOMAIN="geohpcc.local"

function removeallhosts {
	file="$1"

	cp -f $file /tmp/tmp_host
	cat /tmp/tmp_host | grep -v "$IDLINE" > $file
}

function removehost {
	# if either (host & ip) or (host & domain) match, remove entry
	file="$1"
	host="$2"
	domain="$3"
	ip="$4"
	cp -f $file /tmp/tmp_host
	cat /tmp/tmp_host | grep -v "$host $host.$domain $IDLINE" > $file
	cp -f $file /tmp/tmp_host
	cat /tmp/tmp_host | grep -v "$ip $host .* $IDLINE" > $file
}

function addhost {
	file="$1"
	host="$2"
	domain="$3"
	ip="$4"
	removehost "$1" "$2" "$3" "$4"
	echo "$ip $host $host.$domain $IDLINE" >> $file
}

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

	removeallhosts $CNHOSTS
	removeallhosts $HOSTHOSTS
	
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
		ipaddr=`echo $line | awk '{print $2}'`
		hostname=`echo $line | awk '{print $3}'`
		echo $hostname
		mkdir -p ${CNDIR}/state/${hostname}.${DOMAIN}
		addhost "$CNHOSTS" "$hostname" "$DOMAIN" "$ipaddr"
		addhost "$HOSTHOSTS" "$hostname" "$DOMAIN" "$ipaddr"
	done
	IFS=$OLDIFS

	exit 0
fi

echo
echo
echo Manage state files of the computings nodes
echo and other related settings.
echo
echo "    Usage: $0 [CLEAR|CREATE hostdb]"
echo
echo CLEAR:  Remove all state files and host definitions
echo         of all computing nodes.
echo
echo CREATE: Create state file stores and host
echo         definitions for hosts in host db file. Will
echo         not remove definitions not listed in the 
echo         hostdb.
echo
echo "NB! This script will not change any of the DHCP"
echo configurations. Use the dhcp scripts instead.
echo
echo Related files: /etc/hosts ${CNDIR}/cnimage/etc/hosts
echo "               ${CNDIR}/state/*"
echo
echo


