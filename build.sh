#!/bin/bash

set -e

ARCH=$(uname -m)

if [[ "$ARCH" != x86* ]]; then
    echo "cannot build android on $ARCH"
    exit 0
fi

echo "current arch: $ARCH"

OUT_DIR="$(cd "$(dirname "$0")" && pwd)"/../_cache

function build_kernel() {
	echo "build android from source......"
	mkdir -p $OUT_DIR/_android_kernel
	cd $OUT_DIR/_android_kernel
	if [ ! -d .repo ]; then
		repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
		repo sync

		echo "sync done, add patch"
		pwd
		cp $OUT_DIR/../android/15-6.6/BUILD.bazel common/
		cp $OUT_DIR/../android/15-6.6/baize.fragment common/arch/arm64/configs/
		cd common/
		git am $OUT_DIR/../android/15-6.6/0001-fix-android-ubsan-error-when-mount-virtio-blk-device.patch
		cd ..
	fi

	echo "start build android kernel"
	tools/bazel build //common:kernel_aarch64_dist
	tools/bazel run //common:kernel_aarch64_dist
	cd ..

	echo "build ramdisk"
	mkdir -p _ramdisk_cpio
	rm -rf _ramdisk_cpio/*
	cd _ramdisk_cpio
	cpio -idv < ../../rootfs-hub/android/ramdisk-v2.cpio
	rm -rf lib/modules/*
	cp ../_android_kernel/out/kernel_aarch64/dist/*.ko lib/modules/
	cp ../_android_kernel/out/kernel_aarch64/dist/system_dlkm.modules.load lib/modules/modules.load
	pushd .
	cd ../_android_kernel/out/kernel_aarch64/dist/
	KVER=$(strings Image | grep -E "^6\.6\.[0-9]+" | head -n 1 | cut -d' ' -f1)
	mkdir -p lib/modules/$KVER
	rm -rf lib/modules/$KVER/*
	cp *.ko lib/modules/$KVER/
	depmod -b $(pwd) -F $(pwd)/System.map $(strings Image | grep -E "^6\.6\.[0-9]+" | head -n 1 | cut -d' ' -f1)
	cp lib/modules/$KVER/modules.dep ../../../../_ramdisk_cpio/lib/modules/
	popd
	#find . -mindepth 1 | cpio -o -H newc > ../ramdisk-v3.cpio
	sudo sh -c "find . -mindepth 1 | cpio -o -H newc" > ../ramdisk-v3.cpio
	cd ..
	echo "ramdisk built"
}

function transfer_vendor() {
	git lfs pull
	dd if=/dev/zero of=vendor.img bs=1M count=512
	mkfs.ext4 -L vendor vendor.img
	sudo mount -t ext4 -o rw,user_xattr vendor.img mp
	#sudo mount -t erofs -o ro cf-vendor.img ori
	sudo rsync -aXA ./ori/ ./mp/

	e2fsck -f vendor.img
}

function patch_aosp_for_cuttlefish() {
	pushd .
	cd ./external/minigbm
	git apply 0001-fix-mesa-build.patch
	cd ./device/google/cuttlefish
	git apply 0001-feat-build-for-mesa-ext4.patch
	popd
}

function swapfile() {
	# enable
	sudo dd if=/dev/zero of=./swapfile bs=1M count=32768
	sudo chmod 600 ./swapfile
	sudo mkswap ./swapfile
	sudo swapon ./swapfile

	# check
	free -h

	# disable
	sudo swapoff ./swapfile
}

function patch_aosp() {
	pushd .
        cd ./device/linaro/dragonboard
        git am $OUT_DIR/../android/device/linaro/dragonboard/0001-feat-baize.patch
	popd
}

function build_aosp() {
	mkdir -p _aosp
	cd _aosp
	if [ ! -d .repo ]; then
		repo init -u https://android.googlesource.com/platform/manifest -b android-15.0.0_r22 --depth=1
		repo sync -c --no-tags --no-clone-bundle -j$(nproc)
		patch_aosp
	fi
	source build/envsetup.sh
	#lunch aosp_cf_arm64_phone-trunk_staging-userdebug
	lunch db845c-trunk_staging-userdebug
	# build android in background
	#sudo apt-get install screen
	#screen -S aosp
	make -j$(nproc)
	# reconnect screen
	#screen -r aosp
	cd ..
}

build_kernel
pwd
build_aosp

cp $OUT_DIR/_android_kernel/out/kernel_aarch64/dist/Image $OUT_DIR/../rootfs-hub/android/
#mv $OUT_DIR/ramdisk-v3.cpio $OUT_DIR/../rootfs-hub/android/

cp $OUT_DIR/_aosp/out/target/product/db845c/system.img $OUT_DIR/../rootfs-hub/android/userdebug/
cp $OUT_DIR/_aosp/out/target/product/db845c/system_ext.img $OUT_DIR/../rootfs-hub/android/userdebug/
cp $OUT_DIR/_aosp/out/target/product/db845c/product.img $OUT_DIR/../rootfs-hub/android/userdebug/
cp $OUT_DIR/_aosp/out/target/product/db845c/userdata.img $OUT_DIR/../rootfs-hub/android/userdebug/

$OUT_DIR/../android/update_vendor.sh
cp $OUT_DIR/_aosp/out/target/product/db845c/vendor.img $OUT_DIR/../rootfs-hub/android/userdebug/

