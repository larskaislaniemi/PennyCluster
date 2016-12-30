#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

echo Creating partitions on /dev/sda ...

if [ -e /dev/sda ];
then
	/sbin/parted /dev/sda mklabel msdos
	/sbin/parted -a optimal /dev/sda mkpart primary ext4 "0%" "100%"
	/sbin/mkfs.ext4 -L stateless-rw /dev/sda1
else
	echo "FAILED : no such device /dev/sda"
fi

