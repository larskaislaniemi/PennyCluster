#!/bin/bash

## Variables ###

DRYRUN="1"       # set to "0" to actually run the script
                 # otherwise it will only show what would 
                 # be done
CLIENTONLY="0"   # if '1' then host configuration is left 
                 # untouched: only the client root and ram image
                 # will be generated

###############


echo "= Do 'yum update' and reboot before running this!"
echo "  (Unless you are sure you are running the latest kernel...)"
echo "= Make sure you have configured the network"
echo "= Make sure you have modified all the configuration files"
echo "Press Enter to continue or Ctrl-C to abort."
read DUMMY

KERNELVER=`uname -r`
SETUPDIR=`pwd`
CNDIR="/srv/cndata"   # just a convenience; to change, modify also config files!

if [ "$DRYRUN" -eq "0" ];
then
	DBGCMD=""
else
	DBGCMD="echo "
fi

if [ "$CLIENTONLY" -eq "0" ];
then
	echo ====
	echo Installing host packages ...
	$DBGCMD yum install tftp-server xinetd syslinux dhcp tftp nfs-utils dracut-network dracut-config-generic 

	echo ====
	echo Copying host configuration files ...
	$DBGCMD mkdir -p /var/lib/tftpboot/pxelinux.cfg
	$DBGCMD cp -f /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
	$DBGCMD cp -f /boot/vmlinuz-${KERNELVER} /var/lib/tftpboot/vmlinuz || (echo "ERROR: vmlinuz copy failed!" && exit 1)

	BAKDIR=${SETUPDIR}/hostfiles_backup_`date +%F_%N`
	$DBGCMD mkdir -p ${BAKDIR}
	cd ${SETUPDIR}/hostfiles
	for f in *;
	do 
		newfile=`echo $f | sed 's/__/\//g'`
		newfile=/${newfile}
		if [ -e $newfile ];
		then
			$DBGCMD cp -f $newfile ${BAKDIR}/$f
		fi
		$DBGCMD mkdir -p `dirname $newfile`
		$DBGCMD cp $f $newfile
	done
	cd ${SETUPDIR}
fi

echo ====
echo Setting up client image and installation
if [ -d ${CNDIR}/cnimage ];
then
	echo ${CNDIR}/cnimage exists. Remove manually if you want to continue. Exiting...
	exit 1
fi
$DBGCMD mkdir -p ${CNDIR}/cnimage
$DBGCMD mkdir -p ${CNDIR}/state

$DBGCMD yum --installroot=${CNDIR}/cnimage --releasever=7 --downloaddir=/tmp/yumdownload packages install "Minimal Install"
$DBGCMD yum --installroot=${CNDIR}/cnimage --releasever=7 --downloaddir=/tmp/yumdownload install kernel nfs-utils

echo ====
echo Copying client configuration files
cd ${SETUPDIR}/cnfiles
for f in *;
do
	newfile=`echo $f | sed 's/__/\//g'`
	$DBGCMD mkdir -p ${CNDIR}/cnimage/`dirname $newfile`
	$DBGCMD cp $f ${CNDIR}/cnimage/$newfile
done
cd ${SETUPDIR}

# client mtab needs to be written and locked but
# /etc/mtab is on read-only fs -> circumvent by
# linking it to a proc file of same purpose
cd ${CNDIR}/cnimage/etc
$DBGCMD rm -f mtab
$DBGCMD ln -s ../proc/self/mounts ./mtab

cd ${SETUPDIR}

echo ====
echo 'Give client machine root password (will be shown!):'
read PLAINPW
python -c "import crypt; print(crypt.crypt(\"${PLAINPW}\", crypt.mksalt(crypt.METHOD_SHA512)))" > /tmp/cnsetup_tmp01
PW=`cat /tmp/cnsetup_tmp01`
$DBGCMD rm -f /tmp/cnsetup_tmp01
cat ${CNDIR}/cnimage/etc/shadow | sed -re "s@root:\*:@root:"$PW":@" > /tmp/cnsetup_tmp02
$DBGCMD cp -f /tmp/cnsetup_tmp02 ${CNDIR}/cnimage/etc/shadow
$DBGCMD rm -f /tmp/cnsetup_tmp02


if [ "$CLIENTONLY" -eq "0" ]; 
then
	echo ====
	echo Starting and enabling host services ...
	$DBGCMD systemctl enable dhcpd
	$DBGCMD systemctl start dhcpd
	$DBGCMD firewall-cmd --add-service=dhcpd --permanent

	$DBGCMD systemctl enable xinetd
	$DBGCMD systemctl start xinetd
	$DBGCMD firewall-cmd --add-service=tftp --permanent

	$DBGCMD systemctl enable nfs-server
	$DBGCMD systemctl enable rpcbind
	$DBGCMD systemctl start nfs-server
	$DBGCMD systemctl start rpcbind
	$DBGCMD firewall-cmd --add-service=nfs --permanent
	$DBGCMD firewall-cmd --add-service=rpc-bind --permanent

	$DBGCMD firewall-cmd --reload
fi

echo ====
echo Creating initramfs ...
cd ${CNDIR}
dracut -f initramfs-nfs.img
$DBGCMD cp -f initramfs-nfs.img /var/lib/tftpboot/
cd ${SETUPDIR}

echo ====
echo All done.
echo ====