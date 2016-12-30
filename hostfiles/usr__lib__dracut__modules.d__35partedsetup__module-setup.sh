#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    #IMPORTANT! 
    # This MUST BE '255' so that the module will 
    # only be loaded if explicitly told so in 
    # dracut.conf. Default loading would be 
    # dangerous for obvious reasons...
    return 255
}

depends() {
    return 0
}

install() {
    inst_multiple parted mkfs.ext4
    inst_hook cleanup 91 "$moddir/partedsetup.sh"
    echo "======================================"
    echo "WARNING! partedsetup MODULE INSTALLED:"
    echo "PRODUCED INITRAMFS WILL WIPE THE LOCAL"
    echo "DISK EVERY TIME DURING BOOT!          "
    echo "======================================"
}

#installkernel() {
#    # nothing needed
#}

