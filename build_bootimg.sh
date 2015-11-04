#!/bin/sh

android_kitchen_relative_path=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
ANDROID_KITCHEN=`cd $android_kitchen_relative_path && pwd`
KERNEL_ROOT="$ANDROID_KITCHEN/Nexus_5"
BRANCH=""
MKBOOT="$ANDROID_KITCHEN/mkbootimg_tools"
TOOLCHAIN_ROOT="$ANDROID_KITCHEN/toolchains"
RAMDISK="$ANDROID_KITCHEN/hammerhead-ramdisk/ramdisk"
WORK="$ANDROID_KITCHEN/hammerhead-ramdisk"

while [ $# -ne 0 ]
do
    case $1 in
	-b)		# Target branch
	    BRANCH="$2"
	    shift ;;
	--help)		# Show help message
	    echo "$USAGE"
	    exit $? ;;
	-*)		# Input invalid option
	    echo "$0: invalid option: $1" >&2
	    echo "$USAGE"
	    exit 1 ;;
	*)
	    break ;;
    esac
    shift
done
if [ $# -ne 0 ]; then
    case $1 in
	a15)		# Linaro toolchains optimized for cortex-a15 with neon-vfpv4
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep cortex_a15 | tail -n 1`/bin/arm-cortex_a15-linux-gnueabihf-;;
	uber)		# UBERTC arm-eabi
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-eabi- | tail -n 1`/bin/arm-eabi-;;
	uber-android) # UBERTC androideabi
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi- | tail -n 1`/bin/arm-linux-androideabi-;;
	uber-android-4.9) # UBERTC androideabi GCC 4.9 upstream and Linaro patches
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi-4.9 | tail -n 1`/bin/arm-linux-androideabi-;;
	uber-android-4.8) # UBERTC androideabi GCC 4.8 upstream and Linaro, AOSP patches
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi-4.8 | tail -n 1`/bin/arm-linux-androideabi-;;
	google)		# Google Android-NDK toolchains
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep arm-linux-androideabi- | grep -v clang | tail -n 1`/prebuilt/linux-`uname -m`/bin/arm-linux-androideabi-;;
	*)
	    export CROSS_COMPILE=$1;;
    esac
else			# Default toolchain
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi- | tail -n 1`/bin/arm-linux-androideabi-
fi

echo -n "CROSS_COMPILE="
echo $CROSS_COMPILE
[ -n "$CROSS_COMPILE" ] || exit 1
[ -x "${CROSS_COMPILE}gcc" ] || exit 1

if [ ! -d "$KERNEL_ROOT" ] && [ ! -d "$MKBOOT" ] && [ ! -d "$RAMDISK" ] && [ ! -d "$WORK" ]; then
    echo "Do not exist some directories"
    exit 1
fi

cd $KERNEL_ROOT
if [ -n $BRANCH ]; then
    git checkout $BRANCH || exit 1
fi
if [ ! -f $KERNEL_ROOT/.config ]; then
    make ARCH=arm SUBARCH=arm yuskey_hammerhead_defconfig
fi
make menuconfig ARCH=arm SUBARCH=arm || exit 1
JOBS=`cat /proc/cpuinfo | grep -c processor`
make -j${JOBS} ARCH=arm SUBARCH=arm || exit 1

cp -f $KERNEL_ROOT/arch/arm/boot/zImage $WORK

if [ -f $ANDROID_KITCHEN/boot.img ]; then
    mv $ANDROID_KITCHEN/boot.img $ANDROID_KITCHEN/boot.img.old
fi

$MKBOOT/dtbTool -s 2048 -o $WORK/dt.img -p $KERNEL_ROOT/scripts/dtc/ $KERNEL_ROOT/arch/arm/boot/ || exit 1
kernel_size=`\ls -l $WORK/zImage | cut -d ' ' -f 5`
sed -i -e "s/kernel_size.*$/kernel_size=$kernel_size/g" $WORK/img_info
dtb_size=`\ls -l $WORK/dt.img | cut -d ' ' -f 5`
sed -i -e "s/dtb_size.*$/dtb_size=$dtb_size/g" $WORK/img_info
$MKBOOT/mkboot $WORK $ANDROID_KITCHEN/boot.img

#adb reboot bootloader
#fastboot boot $ANDROID_KITCHEN/boot.img

exit 0

