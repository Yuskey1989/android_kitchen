#!/bin/sh

ANDROID_KITCHEN=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
KERNEL_ROOT="$ANDROID_KITCHEN/Yuskey1989/Nexus_5"
MKBOOT="$ANDROID_KITCHEN/mkbootimg_tools"
TOOLCHAIN=$1
for toolchain_path in `echo $ANDROID_KITCHEN/linaro-toolchain/*/bin`
do
    PATH=$PATH:$toolchain_path
done

case $TOOLCHAIN in
    a15)
	export CROSS_COMPILE=arm-cortex_a15-linux-gnueabihf-;;
    linaro)
	export CROSS_COMPILE=arm-linux-gnueabihf-;;
    google)
	export CROSS_COMPILE=arm-linux-androideabi-;;
    ubuntu)
	export CROSS_COMPILE=;;
    *)
	export CROSS_COMPILE=arm-cortex_a15-linux-gnueabihf-;;
esac
echo -n "CROSS_COMPILE="
echo $CROSS_COMPILE

if [ ! -d $KERNEL_ROOT -a ! -d $MKBOOT ]; then
    exit 1
fi

cd $KERNEL_ROOT
if [ ! -f ./.config ]; then
    make yuskey_hammerhead_defconfig
fi
make menuconfig ARCH=arm SUBARCH=arm
if [ -n "$CROSS_COMPILE" ]; then
    #make clean
    make -j4 ARCH=arm SUBARCH=arm
else
    exit 1
fi
cd -

cp -f $KERNEL_ROOT/arch/arm/boot/zImage $MKBOOT/work

$MKBOOT/dtbTool -s 2048 -o $MKBOOT/work/dt.img -p $KERNEL_ROOT/scripts/dtc/ $KERNEL_ROOT/arch/arm/boot/ || exit 1
$MKBOOT/mkboot $MKBOOT/work $MKBOOT/boot.img

#adb reboot bootloader
#fastboot boot $MKBOOT/boot.img

exit 0

