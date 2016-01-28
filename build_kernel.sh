#!/bin/sh

android_kitchen_relative_path=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
ANDROID_KITCHEN=`cd $android_kitchen_relative_path && pwd`
KERNEL_ROOT="$ANDROID_KITCHEN/Nexus_5"
BRANCH=""
MKBOOT="$ANDROID_KITCHEN/mkbootimg_tools"
TOOLCHAIN_ROOT="$ANDROID_KITCHEN/toolchains"
RAMDISK="$ANDROID_KITCHEN/hammerhead-ramdisk/ramdisk"
ANYKERNEL="$ANDROID_KITCHEN/AnyKernel2"
BOOTIMG_WORK="$ANDROID_KITCHEN/hammerhead-ramdisk"
BUILD="zip"

USAGE="
Build Android Kernel Script

USAGE:
    $0 [OPTIONS] [CROSSCOMPILE_PREFIX | SHORTCUT]

OPTIONS:
    --branch, -b
	It is able to set kernel target branch.
	Default is current branch.
    --image, -i
	Build the kernel boot image.
	If you do not set --image or --zip, the kernel is built to the ${BUILD}.
    --zip, -z
	Build the Anykernel2 flashable zip file.
	If you do not set --image or --zip, the kernel is built to the ${BUILD}.
    --help, -h
	Show this help message.

CROSSCOMPILE_PREFIX:
    You can set the prefix of the toolchain.
    Example:
	~/user/android_kitchen/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin/arm-linux-androideabi-

    If you do not set the prefix or the shortcut, the kernel is built with the default toolchain.

SHORTCUT:
    uber
	Build kernel with latest UBERTC arm-eabi.
    uber-android
	Build kernel with latest UBERTC androideabi.
    uber-android-4.9
	Build kernel with UBERTC androideabi 4.9.
    google
	Build kernel with Google Android-NDK toolchain.

    If you do not set the prefix or the shortcut, the kernel is built with the default toolchain.
"

while [ $# -ne 0 ]
do
    case $1 in
	--image | -i)		# Build bootimg
	    BUILD="bootimg" ;;
	--zip | -z)		# Build flashable zip
	    BUILD="zip" ;;
	--branch | -b)		# Target branch
	    BRANCH="$2"
	    shift ;;
	--help | -h)		# Show help message
	    echo "$USAGE"
	    exit $? ;;
	-*)			# Input invalid option
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
	uber)			# Latest UBERTC arm-eabi
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-eabi- | tail -n 1`/bin/arm-eabi-;;
	uber-android)		# Latest UBERTC androideabi
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi- | tail -n 1`/bin/arm-linux-androideabi-;;
	uber-android-4.9)	# UBERTC androideabi GCC 4.9 upstream and Linaro, AOSP patches
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi-4.9 | tail -n 1`/bin/arm-linux-androideabi-;;
	google)			# Latest Google Android-NDK toolchain
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/`\ls $TOOLCHAIN_ROOT | grep arm-linux-androideabi- | grep -v clang | tail -n 1`/prebuilt/linux-`uname -m`/bin/arm-linux-androideabi-;;
	*)			# User's toolchain
	    export CROSS_COMPILE=$1;;
    esac
else				# Default toolchain
	    export CROSS_COMPILE=$TOOLCHAIN_ROOT/uber_toolchain/`\ls $TOOLCHAIN_ROOT/uber_toolchain | grep arm-linux-androideabi- | tail -n 1`/bin/arm-linux-androideabi-
fi

echo -n "CROSS_COMPILE="
echo $CROSS_COMPILE
[ -n "$CROSS_COMPILE" ] || exit 1
[ -x "${CROSS_COMPILE}gcc" ] || exit 1

if [ ! -d "$KERNEL_ROOT" ] && [ ! -d "$MKBOOT" ]; then
    echo "Some directories do not exist."
    exit 1
fi
if [ "$BUILD" != "zip" ] && [ ! -d "$RAMDISK" ] && [ ! -d "$BOOTIMG_WORK" ]; then
    echo "Some directories do not exist."
    exit 1
fi
echo "Build the $BUILD"

cd $KERNEL_ROOT
if [ -n $BRANCH ]; then
    git checkout $BRANCH || exit 1
fi
NAME=`git branch | grep '*' | cut -d ' ' -f 2`
DEVICE=`basename $KERNEL_ROOT`
if [ ! -f $KERNEL_ROOT/.config ]; then
    make ARCH=arm SUBARCH=arm yuskey_hammerhead_defconfig
fi
make menuconfig ARCH=arm SUBARCH=arm || exit 1
JOBS=`cat /proc/cpuinfo | grep -c processor`
make -j${JOBS} ARCH=arm SUBARCH=arm || exit 1

if [ "$BUILD" = "bootimg" ]; then
    cp -f $KERNEL_ROOT/arch/arm/boot/zImage $BOOTIMG_WORK
    if [ -f $ANDROID_KITCHEN/boot.img ]; then
	mv $ANDROID_KITCHEN/boot.img $ANDROID_KITCHEN/boot.img.old
    fi

    $MKBOOT/dtbTool -s 2048 -o $BOOTIMG_WORK/dt.img -p $KERNEL_ROOT/scripts/dtc/ $KERNEL_ROOT/arch/arm/boot/ || exit 1
    kernel_size=`\ls -l $BOOTIMG_WORK/zImage | cut -d ' ' -f 5`
    sed -i -e "s/kernel_size.*$/kernel_size=$kernel_size/g" $BOOTIMG_WORK/img_info
    dtb_size=`\ls -l $BOOTIMG_WORK/dt.img | cut -d ' ' -f 5`
    sed -i -e "s/dtb_size.*$/dtb_size=$dtb_size/g" $BOOTIMG_WORK/img_info
    $MKBOOT/mkboot $BOOTIMG_WORK $ANDROID_KITCHEN/boot.img
fi

if [ "$BUILD" = "zip" ]; then
    rm -f ${ANYKERNEL}/zImage*
    rm -f ${ANYKERNEL}/*dtb
    rm -f ${ANYKERNEL}/modules/*.ko

    cp -f ${KERNEL_ROOT}/arch/arm/boot/zImage-dtb ${ANYKERNEL}/zImage
    find ${KERNEL_ROOT} -name *.ko -print0 | xargs -0 cp -f -t ${ANYKERNEL}/modules

    cd ${ANYKERNEL}
    7za a -tzip -r ${NAME}-${DEVICE}-AnyKernel2-unsigned.zip *
    mv ${ANYKERNEL}/${NAME}-${DEVICE}-AnyKernel2-unsigned.zip ${ANDROID_KITCHEN}

    cd ${ANDROID_KITCHEN}
    java -jar ${ANDROID_KITCHEN}/signapk/aosp-signapk-master/prebuilt/aospsign.jar ${ANDROID_KITCHEN}/signapk/build/target/product/security/testkey.x509.pem ${ANDROID_KITCHEN}/signapk/build/target/product/security/testkey.pk8 ${NAME}-${DEVICE}-AnyKernel2-unsigned.zip build.zip
    ${ANDROID_KITCHEN}/android_packages_apps_OpenDelta/jni/zipadjust build.zip build-fixed.zip
    java -jar ${ANDROID_KITCHEN}/android_packages_apps_OpenDelta/server/minsignapk.jar ${ANDROID_KITCHEN}/signapk/build/target/product/security/testkey.x509.pem ${ANDROID_KITCHEN}/signapk/build/target/product/security/testkey.pk8 build-fixed.zip ${NAME}-${DEVICE}-AnyKernel2-signed.zip

    rm -f build.zip build-fixed.zip
    rm -f ${NAME}-${DEVICE}-AnyKernel2-unsigned.zip
fi

exit 0
