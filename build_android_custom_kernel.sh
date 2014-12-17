#!/bin/sh

android_kitchen_relative_path=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
ANDROID_KITCHEN=`cd $android_kitchen_relative_path && pwd`
KERNEL_ROOT="$ANDROID_KITCHEN/Yuskey1989/Nexus_5"
MKBOOT="$ANDROID_KITCHEN/mkbootimg_tools"
TOOLCHAIN_ROOT="$ANDROID_KITCHEN/toolchains"
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

if [ ! -d $KERNEL_ROOT -a ! -d $MKBOOT ]; then
    exit 1
fi

cd $KERNEL_ROOT
if [ ! -f ./.config ]; then
    make ARCH=arm SUBARCH=arm yuskey_hammerhead_defconfig
fi
make menuconfig ARCH=arm SUBARCH=arm
if [ -n "$CROSS_COMPILE" ]; then
    #make clean
    make -j4 ARCH=arm SUBARCH=arm
else
    exit 1
fi

cp -f $KERNEL_ROOT/arch/arm/boot/zImage $MKBOOT/work

$MKBOOT/dtbTool -s 2048 -o $MKBOOT/work/dt.img -p $KERNEL_ROOT/scripts/dtc/ $KERNEL_ROOT/arch/arm/boot/ || exit 1
$MKBOOT/mkboot $MKBOOT/work $MKBOOT/boot.img

#adb reboot bootloader
#fastboot boot $MKBOOT/boot.img

exit 0

