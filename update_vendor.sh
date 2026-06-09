#!/bin/sh

#set -e

SRC_PATH=~/baize-board/android

cp ~/aosp/out/target/product/db845c/*.img .
mv vendor.img vendor.img.ori

dd if=/dev/zero of=vendor.img bs=1M count=512
mkfs.ext4 -L vendor vendor.img

mkdir -p dst ori
sudo mount -t ext4 -o rw,user_xattr vendor.img dst
sudo mount -t ext4 -o ro vendor.img.ori ori
sudo rsync -aXA ./ori/ ./dst/
cd dst
sudo cp $SRC_PATH/img_update/etc/fstab.baize etc/
sudo cp $SRC_PATH/img_update/etc/init/init.baize.rc etc/init/

sudo cp -r $SRC_PATH/vendor/linaro/shared/20240817/mesa_prebuilt/lib64/* lib64/

sudo setfattr -h -n security.selinux -v "u:object_r:vendor_configs_file:s0" etc/fstab.baize
sudo setfattr -h -n security.selinux -v "u:object_r:vendor_configs_file:s0" etc/init/init.baize.rc
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/libgallium_dri.so
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/libglapi.so
sudo setfattr -h -n security.selinux -v "u:object_r:vendor_file:s0" lib64/hw/vulkan.freedreno.so
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/egl
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/egl/libGLESv1_CM_mesa.so
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/egl/libGLESv2_mesa.so
sudo setfattr -h -n security.selinux -v "u:object_r:same_process_hal_file:s0" lib64/egl/libEGL_mesa.so

cd ..

sudo umount ori
sudo umount dst

cp product.img ~/temp/
cp system.img ~/temp/
cp system_ext.img ~/temp/
cp userdata.img ~/temp/
cp vbmeta.img ~/temp/
cp vendor.img ~/temp/

