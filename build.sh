#!/bin/bash

set -e

echo "check gsi......"
if [ ! -f ../rootfs-hub/android/gsi/system.img ]; then
        unzip ../rootfs-hub/android/gsi/*.zip -d ../rootfs-hub/android/gsi/
fi

ARCH=$(uname -m)

if [[ "$ARCH" != x86* ]]; then
    echo "cannot build android on $ARCH"
    exit 0
fi

echo "current arch: $ARCH"

if [ "build" == $1 ]; then
	echo "build android from source......"
	mkdir _android_kernel
	cd _android_kernel
	repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
	repo sync

	echo "sync done, add patch"
	cp ../15-6.6/BUILD.bazel common/
	cp ../15-6.6/baize.fragment common/arch/arm64/configs/
	cd common/
	git am ../../15-6.6/0001-fix-android-ubsan-error-when-mount-virtio-blk-device.patch
	cd ..

	echo "start build android kernel"
	tools/bazel build //common:kernel_aarch64_dist
	tools/bazel run //common:kernel_aarch64_dist

	echo "build ramdisk"
	cd ..
	mkdir _ramdisk_cpio
	cd _ramdisk_cpio
	cpio -idv < ../../rootfs-hub/android/vendor_boot/vendor_ramdisk.cpio
	rm -rf lib/modules/*
	cp ../_android_kernel/out/kernel_aarch64/dist/*.ko lib/modules/
	cp ../_android_kernel/out/kernel_aarch64/dist/system_dlkm.modules.load lib/modules/modules.load
	pushd .
	cd ../_android_kernel/out/kernel_aarch64/dist/
	KVER=$(strings Image | grep -E "^6\.6\.[0-9]+" | head -n 1 | cut -d' ' -f1)
	mkdir -p lib/modules/$KVER
	cp *.ko lib/modules/$KVER/
	depmod -b $(pwd) -F $(pwd)/System.map $(strings Image | grep -E "^6\.6\.[0-9]+" | head -n 1 | cut -d' ' -f1)
	cp lib/modules/$KVER/modules.dep ../../../../_ramdisk_cpio/lib/modules/
	popd
	find . -mindepth 1 | cpio -o -H newc > ../ramdisk-v2.cpio
	sudo sh -c "find . -mindepth 1 | cpio -o -H newc" > ../ramdisk-v3.cpio
	cd ..
	mv ramdisk-v2.cpio ../rootfs-hub/android/
	echo "ramdisk built"
else
	echo "use ramdisk from hub......"
fi

function transfer_vendor() {
	dd if=/dev/zero of=vendor.img bs=1M count=1536
	mkfs.ext4 -L vendor vendor.img
	sudo mount -t ext4 -o rw vendor.img mp
	sudo rsync -aXA ./vv/ ./mp/
}

