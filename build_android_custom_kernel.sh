#!/bin/sh

android_kitchen_relative_path=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
ANDROID_KITCHEN=`cd $android_kitchen_relative_path && pwd`
KERNEL_ROOT="$ANDROID_KITCHEN/Yuskey1989/Nexus_5"
MKBOOT="$ANDROID_KITCHEN/mkbootimg_tools"
TOOLCHAIN_ROOT="$ANDROID_KITCHEN/toolchains"
RAMDISK="$ANDROID_KITCHEN/hammerhead-ramdisk/ramdisk"
WORK="$ANDROID_KITCHEN/hammerhead-ramdisk"

for toolchain_path in `echo $TOOLCHAIN_ROOT/*/bin $TOOLCHAIN_ROOT/*/*/*/bin`
do
    PATH=$PATH:$toolchain_path
done

case $1 in
    a15)
	export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep cortex_a15 | tail -n 1`/bin/arm-cortex_a15-linux-gnueabihf-;;
    linaro)
	export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep gcc-linaro-arm-linux-gnueabihf- | tail -n 1`/bin/arm-linux-gnueabihf-;;
    sabermod)
	export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep sabermod | tail -n 1`/bin/arm-linux-androideabi-;;
    google)
	export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep arm-linux-androideabi- | grep -v clang | tail -n 1`/prebuilt/linux-`uname -m`/bin/arm-linux-androideabi-;;
    *)
	# Default toolchain
	export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep cortex_a15 | tail -n 1`/bin/arm-cortex_a15-linux-gnueabihf-;;
esac
echo -n "CROSS_COMPILE="
echo $CROSS_COMPILE
[ -n "$CROSS_COMPILE" ] || exit 1

if [ ! -d "$KERNEL_ROOT" -a ! -d "$MKBOOT" -a ! -d "$RAMDISK" -a ! -d "$WORK" ]; then
    echo "Do not exist some directories"
    exit 1
fi

cd $KERNEL_ROOT
if [ ! -f ./.config ]; then
    make ARCH=arm SUBARCH=arm yuskey_hammerhead_defconfig
fi
make menuconfig ARCH=arm SUBARCH=arm
make -j4 ARCH=arm SUBARCH=arm

cp -f $KERNEL_ROOT/arch/arm/boot/zImage $WORK

mkdir -p $RAMDISK/system/lib/modules
for module in `find $KERNEL_ROOT/drivers -iname *.ko`
do
    cp -f $module $RAMDISK/system/lib/modules
done

kernel_size=`\ls -l $WORK/zImage | cut -d ' ' -f 5`
sed -i -e "s/kernel_size.*$/kernel_size=$kernel_size/g" $WORK/img_info
$MKBOOT/dtbTool -s 2048 -o $WORK/dt.img -p $KERNEL_ROOT/scripts/dtc/ $KERNEL_ROOT/arch/arm/boot/ || exit 1
$MKBOOT/mkboot $WORK $MKBOOT/boot.img

#adb reboot bootloader
#fastboot boot $MKBOOT/boot.img

exit 0

