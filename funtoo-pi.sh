#!/bin/bash
ISO_8601=`date -u "+%FT%TZ"` #ISO 8601 Script Start UTC Time
utc=`date -u "+%Y.%m.%dT%H.%M.%SZ"` #UTC Time (filename safe)
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Path to THIS script.
#   Copyright 2013 Roy Pfund
#
#   Licensed under the Apache License, Version 2.0 (the  "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable  law  or  agreed  to  in  writing,
#   software distributed under the License is distributed on an  "AS
#   IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,  either
#   express or implied. See the License for  the  specific  language
#   governing permissions and limitations under the License.
#_______________________________________________________________________________
# invoke with "sudo bash /path/to/funtoo-pi.sh /dev/sdX"
# run "sudo blkid" to get a list of possible /dev/sdX and choose the correct one
# you wish to install Funtoo for Raspberry Pi on.
blkidDev=$1

#http://www.funtoo.org/wiki/Raspberry_Pi
#http://www.funtoo.org/wiki/Funtoo_Linux_Installation_on_ARM
#http://wiki.gentoo.org/wiki/Raspberry_Pi_Quick_Install_Guide
#http://wiki.gentoo.org/wiki/Raspberry_Pi_Cross_building
txzExtract (){ infile=$1; outfile=$2
#txzExtract "/path/to/somearchive.tar.xz" "/path/to/some_directory"
	echo "";
	nice -19 xz -dc $infile | tar xvpC "$outfile" \
	2>&1 | while read line; do
		x=$((x+1))
		echo -en "\r$x extracted";
	done; echo "";
} #_____________________________________________________________________________

#partion disks
sudo sfdisk ${blkidDev} -u M <<EOF
,31,L
,256,S
,,L
EOF
#format disks
sleep 2 && sudo mkfs.vfat -F 16 -n boot ${blkidDev}1
#sleep 2 && sudo dd bs=512 count=1 if=/dev/zero of=${blkidDev}1
sleep 2 && sudo mkswap -L swap ${blkidDev}2
sleep 2 && sudo mkfs.ext4 -L pi ${blkidDev}3

#add boot flag to 1st partition
sudo sfdisk ${blkidDev} -A 1

#Mounting the partitions
sleep 2 && mkdir /mnt/gentoo && sleep 2 && sudo mount ${blkidDev}3 /mnt/gentoo
sleep 2 && mkdir /mnt/gentoo/boot && sleep 2 && sudo mount ${blkidDev}1 /mnt/gentoo/boot

#Extract Stage 3 Image
#Gentoo
	#cd "${owd}"
	#wget http://gentoo.osuosl.org/releases/arm/autobuilds/current-stage3-armv6j_hardfp/stage3-armv6j_hardfp-20130816.tar.bz2 (You will have to change the date.)
	#tar xfpj stage3-armv6j_hardfp-*.tar.bz2 -C /mnt/gentoo/
#Funtoo armv6j_hardfp
	#If [ sha_sum(${owd}/stage3-latest-*.tar.xz) = sha_sum(http://ftp.osuosl.org/pub/funtoo/funtoo-current/arm-32bit/armv6j_hardfp/stage3-latest.tar.xz)
	#then
		txzExtract "${owd}/stage3-latest-*.tar.xz" "/mnt/gentoo"
	#else
#		wget -O ${owd}/stage3-latest-${utc}.tar.xz http://ftp.osuosl.org/pub/funtoo/funtoo-current/arm-32bit/armv6j_hardfp/stage3-latest.tar.xz
#		txzExtract "${owd}/stage3-latest-${utc}.tar.xz" "/mnt/gentoo"
	#fi
#Install Portage
#Gentoo
	#wget http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2 
	#tar xjf portage-latest.tar.bz2 -C /mnt/gentoo/usr
#Funtoo
	#If [ sha_sum(${owd}/portage-latest-*.tar.xz) = sha_sum(http://ftp.osuosl.org/pub/funtoo/funtoo-current/snapshots/portage-latest.tar.xz)
	#then
		txzExtract "${owd}/portage-latest-*.tar.xz" "/mnt/gentoo/usr"
	#else
#		wget -O ${owd}/portage-latest-${utc}.tar.xz http://ftp.osuosl.org/pub/funtoo/funtoo-current/snapshots/portage-latest.tar.xz
#		txzExtract "${owd}/portage-latest-${utc}.tar.xz" "/mnt/gentoo/usr"
	#fi
	cd /mnt/gentoo/usr/portage
	sudo git checkout funtoo.org

#Install kernel and modules
#The Raspberry Pi Foundation maintain a branch of the Linux kernel that will run on the Raspberry Pi, including a compiled version which we use here.
cd /tmp && rm -rf /tmp/firmware
git clone --depth 1 git://github.com/raspberrypi/firmware/
cd /tmp/firmware/boot
cp ./* /mnt/gentoo/boot/
cp -r ../modules /mnt/gentoo/lib/

#set fstab
sudo tee "/mnt/gentoo/etc/fstab" > /dev/null <<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid -o value -s UUID' to print the universally unique identifier
# for a device; this may be used with UUID= as a more robust way to name
# devices that works even if disks are added and removed. See fstab(5).
#
# <file system>		<mount point>	<type>	<options>				<dump>	<pass>
/dev/mmcblk0p1		/boot			auto	noauto,noatime			1		2
/dev/mmcblk0p2		none			swap	sw						0		0
/dev/mmcblk0p3		/				ext4	noatime					0		1
EOF
#Set boot options
sudo tee "/mnt/gentoo/boot/cmdline.txt" > /dev/null <<EOF
dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p3 rootfstype=ext4 elevator=deadline rootwait
EOF
#set root passwd
passwd_raspberry="$(python -c "import crypt, getpass, pwd; print crypt.crypt('raspberry', '\$6\$SALTsalt\$')")"
sudo sed -i "s/root.*/root:${passwd_raspberry}:14698:0:::::/" /mnt/gentoo/etc/shadow
#enable SSH & ethernet
sudo ln -sf /mnt/gentoo/etc/init.d/sshd /mnt/gentoo/etc/runlevels/default
sudo ln -sf /mnt/gentoo/etc/init.d/dhcpcd /mnt/gentoo/etc/runlevels/default
#Use swclock
sudo ln -sf /mnt/gentoo/etc/init.d/swclock /mnt/gentoo/etc/runlevels/boot
sudo rm /mnt/gentoo/etc/runlevels/boot/hwclock
sudo mkdir -p /mnt/gentoo/lib/rc/cache
sudo touch /mnt/gentoo/lib/rc/cache/shutdowntime
#set hostname
sudo sed -i "s/hostname=\"localhost\".*/hostname=\"raspberrypi\"/" /mnt/gentoo/etc/conf.d/hostname
#set /boot/config.txt w/ modest overclock
openssl enc -base64 -A -d <<EOF > '/mnt/gentoo/boot/config.txt'
IyB1bmNvbW1lbnQgaWYgeW91IGdldCBubyBwaWN0dXJlIG9uIEhETUkgZm9yIGEgZGVmYXVsdCAic2FmZSIgbW9kZQojaGRtaV9zYWZlPTEKCiMgdW5jb21tZW50IHRoaXMgaWYgeW91ciBkaXNwbGF5IGhhcyBhIGJsYWNrIGJvcmRlciBvZiB1bnVzZWQgcGl4ZWxzIHZpc2libGUKIyBhbmQgeW91ciBkaXNwbGF5IGNhbiBvdXRwdXQgd2l0aG91dCBvdmVyc2NhbgpkaXNhYmxlX292ZXJzY2FuPTEKCiMgdW5jb21tZW50IHRoZSBmb2xsb3dpbmcgdG8gYWRqdXN0IG92ZXJzY2FuLiBVc2UgcG9zaXRpdmUgbnVtYmVycyBpZiBjb25zb2xlCiMgZ29lcyBvZmYgc2NyZWVuLCBhbmQgbmVnYXRpdmUgaWYgdGhlcmUgaXMgdG9vIG11Y2ggYm9yZGVyCiNvdmVyc2Nhbl9sZWZ0PTE2CiNvdmVyc2Nhbl9yaWdodD0xNgojb3ZlcnNjYW5fdG9wPTE2CiNvdmVyc2Nhbl9ib3R0b209MTYKCiMgdW5jb21tZW50IHRvIGZvcmNlIGEgY29uc29sZSBzaXplLiBCeSBkZWZhdWx0IGl0IHdpbGwgYmUgZGlzcGxheSdzIHNpemUgbWludXMKIyBvdmVyc2Nhbi4KI2ZyYW1lYnVmZmVyX3dpZHRoPTEyODAKI2ZyYW1lYnVmZmVyX2hlaWdodD03MjAKCiMgdW5jb21tZW50IGlmIGhkbWkgZGlzcGxheSBpcyBub3QgZGV0ZWN0ZWQgYW5kIGNvbXBvc2l0ZSBpcyBiZWluZyBvdXRwdXQKI2hkbWlfZm9yY2VfaG90cGx1Zz0xCgojIHVuY29tbWVudCB0byBmb3JjZSBhIHNwZWNpZmljIEhETUkgbW9kZSAodGhpcyB3aWxsIGZvcmNlIFZHQSkKI2hkbWlfZ3JvdXA9MQojaGRtaV9tb2RlPTEKCiMgdW5jb21tZW50IHRvIGZvcmNlIGEgSERNSSBtb2RlIHJhdGhlciB0aGFuIERWSS4gVGhpcyBjYW4gbWFrZSBhdWRpbyB3b3JrIGluCiMgRE1UIChjb21wdXRlciBtb25pdG9yKSBtb2RlcwojaGRtaV9kcml2ZT0yCgojIHVuY29tbWVudCB0byBpbmNyZWFzZSBzaWduYWwgdG8gSERNSSwgaWYgeW91IGhhdmUgaW50ZXJmZXJlbmNlLCBibGFua2luZywgb3IKIyBubyBkaXNwbGF5CiNjb25maWdfaGRtaV9ib29zdD00CgojIHVuY29tbWVudCBmb3IgY29tcG9zaXRlIFBBTAojc2R0dl9tb2RlPTIKCiN1bmNvbW1lbnQgdG8gb3ZlcmNsb2NrIHRoZSBhcm0uCiMjIk5vbmUiICI3MDBNSHogQVJNLCAyNTBNSHogY29yZSwgNDAwTUh6IFNEUkFNLCAwIG92ZXJ2b2x0IgojYXJtX2ZyZXE9NzAwCiNjb3JlX2ZyZXE9MjUwCiNzZHJhbV9mcmVxPTQwMAojb3Zlcl92b2x0YWdlPTAKIyMiTW9kZXN0IiAiODAwTUh6IEFSTSwgMzAwTUh6IGNvcmUsIDQwME1IeiBTRFJBTSwgMCBvdmVydm9sdCIKYXJtX2ZyZXE9ODAwCmNvcmVfZnJlcT0zMDAKc2RyYW1fZnJlcT00MDAKb3Zlcl92b2x0YWdlPTAKIyMiTWVkaXVtIiAiOTAwTUh6IEFSTSwgMzMzTUh6IGNvcmUsIDQ1ME1IeiBTRFJBTSwgMiBvdmVydm9sdCIKI2FybV9mcmVxPTkwMAojY29yZV9mcmVxPTMzMwojc2RyYW1fZnJlcT00NTAKI292ZXJfdm9sdGFnZT0yCiMjIkhpZ2giICI5NTBNSHogQVJNLCA0NTBNSHogY29yZSwgNDUwTUh6IFNEUkFNLCA2IG92ZXJ2b2x0IgojYXJtX2ZyZXE9OTUwCiNjb3JlX2ZyZXE9NDUwCiNzZHJhbV9mcmVxPTQ1MAojb3Zlcl92b2x0YWdlPTYKIyMiVHVyYm8iICIxMDAwTUh6IEFSTSwgNTAwTUh6IGNvcmUsIDUwME1IeiBTRFJBTSwgNiBvdmVydm9sdCIKI2FybV9mcmVxPTEwMDAKI2NvcmVfZnJlcT01MDAKI3NkcmFtX2ZyZXE9NTAwCiNvdmVyX3ZvbHRhZ2U9NgoKIyBmb3IgbW9yZSBvcHRpb25zIHNlZSBodHRwOi8vZWxpbnV4Lm9yZy9SUGlfY29uZmlnLnR4dAo=
EOF
#cleanup
sleep 2 && sudo umount /mnt/gentoo/boot && sleep 2 && sudo umount /mnt/gentoo && sleep 2 && sudo rm -rf /mnt/gentoo
#sudo rm -rf /mnt/gentoo

#??emerge --ask raspberrypi-userland


#		xz -dc ${owd}/wheezy-raspbian.boot.xz | sudo dd bs=4M of=${blkidDev}
#		sleep 2
#		echo -e "4 56\n60\n0 0\n0 0\ny\n" | sudo sfdisk ${blkidDev} -u C
#		sleep 2
#		sudo e2fsck -f -y -v ${blkidDev}2
#		sleep 2
#		sudo resize2fs ${blkidDev}2
