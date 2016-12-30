#!/bin/bash

MYNAME=`basename $0`

HOSTSF="/etc/dhcp/dhcpd.hosts.conf" # convenience, if changed, change dhcp.conf contents as well

HOSTLINETEMPLATE="host \$hostname { hardware ethernet \$hwaddr\; fixed-address \$ipaddr\; option domain-name \\\"geohpcc.local\\\"\; option host-name \\\"\$hostname\\\"\; }"

if [ "$MYNAME" == "dhcpconf2db.sh" ]; then
	if [ "$1" == "--help" ];
	then
		echo Generates hostdb from DHCP config
		echo 
		echo   Usage: $0 
		echo
		exit 0
	fi
	OLDIFS=$IFS
	IFS=$'\n'
	for line in `cat $HOSTSF`;
	do
		hostname=`echo $line | sed -re "s/^host ([a-zA-Z0-9-]{1,}) .*/\\1/g"`
		ipaddr=`echo $line | sed -re "s/^host .*fixed-address ([0-9\.]{7,15}).*/\\1/g"`
		hwaddr=`echo $line | sed -re "s/^host .*hardware ethernet ([0-9A-Za-z:]{17}).*/\\1/g"`
		echo $hwaddr $ipaddr $hostname DHCPCONF
	done
	IFS=$OLDIFS

	exit 0
fi

if [ "$MYNAME" == "dhcplog2db.sh" ]; then
	HOSTDB="$1"
	if [ "$HOSTDB" == "--help" ];
	then
		echo Generates hostdb from DHCP logs
		echo 
		echo   Usage: $0 [hostdb file]
		echo
		echo If hostdb file is given, existing entries
		echo that occur in both the db and the DHCP logs
		echo will be repeated.
		echo
		echo "Existing entries from DHCP configs"
		echo "will be repeated anyhow (and will take"
		echo "precedence over existing entries in db)"
		exit 0
	fi
	if [ "$HOSTDB" == "" ];
	then
		HOSTDB="/dev/null"
	fi
	cat /var/log/messages | grep "DHCPDISCOVER from" | \
		sed -re "s/[A-Za-z]{3} [0-9]{1,2} (..:..:..) .*DHCPDISCOVER from (..:..:..:..:..:..) via.*/\\1 \\2/g" \
		> /tmp/dhcplog2db_tmp.lst

	cat /tmp/dhcplog2db_tmp.lst | sort | awk '{print $2}' | uniq > /tmp/dhcplog2db_tmp2.lst

	PRINTEDHWADDRS=""
	for hwaddr in `cat /tmp/dhcplog2db_tmp2.lst`;
	do
		grep -i "$hwaddr" $HOSTSF > /dev/null
		if [ "$?" -eq "0" ];
		then
			# hwaddr is in DHCP config
			hostname=`cat $HOSTSF | grep -i "$hwaddr" | sed -re "s/^host ([a-zA-Z0-9-]{1,}) .*/\\1/g"`
			ipaddr=`cat $HOSTSF | grep -i "$hwaddr" | sed -re "s/^host .*fixed-address ([0-9\.]{7,15}).*/\\1/g"`
			echo $hwaddr $ipaddr $hostname DHCPCONF
			PRINTEDHWADDRS="$PRINTEDHWADDRS $hwaddr"
		else
			# hwaddr is NOT in DHCP config
			grep -i "$hwaddr" $HOSTDB > /dev/null
			if [ "$?" -eq "0" ];
			then
				# but hwaddr is in host DB
				echo `cat hosts.db | grep -i "$hwaddr" | awk '{print $1 " " $2 " " $3}'` DHCPLOG+OLDDB
				PRINTEDHWADDRS="$PRINTEDHWADDRS $hwaddr"
			else
				echo $hwaddr x.x.x.x nohostname DHCPLOG
				PRINTEDHWADDRS="$PRINTEDHWADDRS $hwaddr"
			fi
		fi
	done
	
	# go through existing host db (if any) and repeat all entries
	# that haven't been printed yet
	OLDIFS=$IFS
	IFS=$'\n'
	for line in `cat $HOSTDB`;
	do
		hwaddr=`echo $line | awk '{print $1}'`
		ipaddr=`echo $line | awk '{print $2}'`
		hostname=`echo $line | awk '{print $3}'`
		echo "$PRINTEDHWADDRS" | grep -i "$hwaddr" > /dev/null
		if [ "$?" == "1" ];
		then
			echo $hwaddr $ipaddr $hostname OLDDB
		fi
	done
	IFS=$OLDIFS

	exit 0
	
fi

if [ "$MYNAME" == "db2dhcpconf.sh" ];
then
	HOSTDB="$1"
	if [ "$HOSTDB" == "" ];
	then
		HOSTDB="--help"	
	fi
	if [ "$HOSTDB" == "--help" ];
	then
		echo "Generates DHCP config (dhcpd.hosts.conf) from host db"
		echo 
		echo   Usage: $0 hostdb_file
		echo
		echo Entries with ip address x.x.x.x will be skipped.
		exit 0
	fi

	OLDIFS=$IFS
	IFS=$'\n'
	for line in `cat $HOSTDB`;
	do
		hwaddr=`echo $line | awk '{print $1}'`
		ipaddr=`echo $line | awk '{print $2}'`
		hostname=`echo $line | awk '{print $3}'`
		if [ "$ipaddr" != "x.x.x.x" ];
		then
			eval "echo $HOSTLINETEMPLATE"
		fi
	done
	IFS=$OLDIFS

	exit 0
fi

echo "This script won't do anything unless you call it as"
echo "  db2dhcpconf.sh"
echo "  dhcpconf2db.sh"
echo "  dhcplog2db.sh"
echo "See dhcpsearch.txt for instructions."
