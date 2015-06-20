#!/bin/sh

########## PATH ##########
RUN_DIR=`pwd`
android_kitchen_relative_path=`which $0 | xargs dirname 2> /dev/null || echo $0 | xargs dirname 2> /dev/null`
ANDROID_KITCHEN=`cd $android_kitchen_relative_path && pwd`
KERNEL_ROOT="$ANDROID_KITCHEN/Nexus_5"
if [ ! -d $KERNEL_ROOT ]; then
    echo "Can not find kernel root path"
    exit 1
fi

##### SETTINGS #####
### Manual ###
BASE_BRANCH="lp-test"
# cherry-pick from here
# importance order
CHERRY_BRANCHES="engstk-L/code_blue-l flar2/ElementalX-2.00 franciscofranco/lollipop Cl3Kener/release neobuddy89/lollipop"
# cherry-pick automatically
# set merge branch name to enable
#MERGE_INTO="lp-automerge"
# save commits log files to here
COMMITS_DIR="$KERNEL_ROOT/../commits"
# cherry-pick if duplicated unmerged commits are more than this number
# unset to always calculate number of $CHERRY_BRANCHES - 1
#IMPORTANCE_THRESHOLD="3"
# reduce execution time of this script, maybe less accuracy (related to $BASE_AOSP)
# search unmerged commits which is newer than $BASE_COMMIT from $BASE_AOSP
# set "true" to enable
FAST="true"
# set AOSP branch or tag
BASE_AOSP="android-msm-hammerhead-3.4-lollipop-release"
BASE_AOSP="android-l-preview_r2.2"
# compare base branch with auto cherry-picked branch (search unmerged commits of auto cherry-picked branch)
# set "true" to enable
DIFF="true"
# merge interactive
# set "true" to enable
#INTERACTIVE="true"

##### USAGE #####
USAGE="\
Kernel Cherry-picking Wrapper
USAGE:  sh $0 [option] {cherry-pick list file}
	option:
		-d			Compare base branch with auto cherry-picked branch (Search unmerged commits of auto cherry-picked branch)
		-i			Merge interactive
		-m [merging branch]	Enable auto merging into [merging branch] (Default: $MERGE_INTO)
		-t [threshold]		Importance threshold (Default: $IMPORTANCE_THRESHOLD)
		--accuracy		Search all cherry-pick commits (Not use base commit, slow)
		--disable-auto-merge	Disable auto merging
		--fast			Speed up searching cherry-pick commits (Use base commit, fast, not accuracy)
		--help			Show this help message
	cherry-pick list file:
		format is \"git log --oneline\"
"

### COMMAND LINE OPTIONS ###
while [ $# -ne 0 ]
do
    case $1 in
	-d)		# Compare base branch with auto cherry-picked branch
	    DIFF="true" ;;
	-i)		# Merge interactive
	    INTERACTIVE="true" ;;
	-m)		# Auto merging branch name
	    MERGE_INTO="$2"
	    shift ;;
	-t)		# Importance threshold
	    IMPORTANCE_THRESHOLD="$2"
	    shift ;;
	--accuracy)
	    FAST="false" ;;
	--disable-auto-merge)
	    MERGE_INTO="" ;;
	--fast)
	    FAST="true" ;;
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
    CHERRY_FILE="$RUN_DIR/$1"
    if [ ! -f "$CHERRY_FILE" ]; then
	echo "Can not find cherry-pick list file $CHERRY_FILE"
	exit 1
    fi
fi

### Automatic ###
cd $KERNEL_ROOT
if [ ! -n "$CHERRY_FILE" ]; then
    git fetch --all
fi
# set base commit from $BASE_AOSP automatically
BASE_COMMIT=`git log --oneline $BASE_AOSP | head -n 1 | cut -d ' ' -f 2-`
MAX_IMPORTANCE_THRESHOLD=`echo "$CHERRY_BRANCHES" | wc -w`
expr $IMPORTANCE_THRESHOLD + 0 2>&1 > /dev/null || IMPORTANCE_THRESHOLD="0"
if [ "$IMPORTANCE_THRESHOLD" -lt "1" ] || [ "$IMPORTANCE_THRESHOLD" -gt "$MAX_IMPORTANCE_THRESHOLD" ]; then
    IMPORTANCE_THRESHOLD=`expr "$MAX_IMPORTANCE_THRESHOLD" - 1` || exit $?
fi

##### MAIN #####
echo "Base branch is $BASE_BRANCH"
echo "Cherry-pick from $CHERRY_BRANCHES"
if [ -n "$MERGE_INTO" ]; then
    echo "Merge into $MERGE_INTO"
fi
if [ $# -eq 0 ]; then ########## When argument is nothing
echo "Save commits log files to $COMMITS_DIR"
echo "Good cherry-picking if duplicated unmerged commits are more than $IMPORTANCE_THRESHOLD commits"
if [ "$FAST" = "true" ]; then
    echo "Reduce a lot of execution time, maybe less accuracy"
    echo "Related to AOSP base commit which is newest commit of $BASE_AOSP"
fi

echo "Making commits log directory"
mkdir -p $COMMITS_DIR
echo "Complete"
echo "Saving commits log of base branch to \"merged\""
git log --oneline $BASE_BRANCH > $COMMITS_DIR/merged || exit $?
echo "Complete"

### Generate seed ###
echo "Generating \"seed\""
for branch in $CHERRY_BRANCHES
do
    remote=`dirname $branch`
    git log --oneline $branch > $COMMITS_DIR/$remote || exit $?
    cat $COMMITS_DIR/$remote $COMMITS_DIR/merged | sed -e "/^$/d" | cut -d ' ' -f 2- | sort | uniq -u > $COMMITS_DIR/seed_$remote
    echo "seed_$remote is generated"
done
cat $COMMITS_DIR/seed_* > $COMMITS_DIR/seed
echo "Complete"

### Generate prune ###
rm -f $COMMITS_DIR/prune_list
echo "Generating \"prune\""
while read line
do
    merged=`echo "$line" | cut -d ' ' -f 2-`
    if [ "$FAST" = "true" ] && [ "$merged" = "$BASE_COMMIT" ]; then
	echo "Hit base commit"
	break
    fi
    cat $COMMITS_DIR/seed | grep -n -F "$merged" | cut -d ':' -f 1 >> $COMMITS_DIR/prune_list
done < $COMMITS_DIR/merged
cat $COMMITS_DIR/prune_list | sort -V | sed -e "s/$/d/g" > $COMMITS_DIR/prune
echo "Complete"
rm -f $COMMITS_DIR/prune_list

### Generate cherry ###
echo "Generating \"cherry\""
cat $COMMITS_DIR/seed | sed -f $COMMITS_DIR/prune > $COMMITS_DIR/cherry
rm -f $COMMITS_DIR/prune
rm -f $COMMITS_DIR/ripe_cherry $COMMITS_DIR/immature_cherry
cat $COMMITS_DIR/cherry | sort | uniq -c | sed -e 's/^[ \t]*//g' | sort > $COMMITS_DIR/cherry_selection
while read line
do
    importance=`echo "$line" | cut -d ' ' -f 1`
    if [ "$importance" -ge "$IMPORTANCE_THRESHOLD" ]; then
	echo "$line" | cut -d ' ' -f 2- >> $COMMITS_DIR/ripe_cherry
    else
	echo "$line" | cut -d ' ' -f 2- >> $COMMITS_DIR/immature_cherry
    fi
done < $COMMITS_DIR/cherry_selection
echo "Complete"
rm -f $COMMITS_DIR/cherry_selection

rm -f $COMMITS_DIR/passed_cherry $COMMITS_DIR/rejected_cherry
if [ $# -eq 0 ]; then
    CHERRY_FILE="$COMMITS_DIR/passed_cherry"
fi
echo "Restoring hash of commits"
while read restore
do
    for branch in $CHERRY_BRANCHES
    do
	remote=`dirname $branch`
# FIX TO HIT REVERT COMMIT TWICE
# UNIQ AGAIN?
	cat $COMMITS_DIR/$remote | grep -F "$restore" >> $COMMITS_DIR/passed_cherry && break
    done
done < $COMMITS_DIR/ripe_cherry
echo "passed_cherry is generated"
while read restore
do
    for branch in $CHERRY_BRANCHES
    do
	remote=`dirname $branch`
# FIX TO HIT REVERT COMMIT TWICE
# UNIQ AGAIN?
	cat $COMMITS_DIR/$remote | grep -F "$restore" >> $COMMITS_DIR/rejected_cherry && break
    done
done < $COMMITS_DIR/immature_cherry
echo "rejected_cherry is generated"
echo "Complete"
# IF cat ripe_cherry | wc -l == cat passed_cherry | wc -l , cat immature_cherry | wc -l == cat rejected_cherry | wc -l
# DELETE ripe_cherry, immature_cherry HERE
#rm -f $COMMITS_DIR/ripe_cherry $COMMITS_DIR/immature_cherry
fi ########## When argument is nothing

### Auto cherry-pick ###
if [ -n "$MERGE_INTO" ]; then
    echo "Cherry-pick automatically"
    echo "Copying auto cherry-pick branch from $BASE_BRANCH to $MERGE_INTO"
    git checkout $BASE_BRANCH
    git branch $MERGE_INTO
    echo "Done"
    git checkout $MERGE_INTO

echo "Cherry-picking"
while [ ! "$success" = "0" ]
do
    success="0"
for file in $CHERRY_FILE
do
    for hash in `cat $file | cut -d ' ' -f 1`
    do
	answer="y"
	if [ "$INTERACTIVE" = "true" ]; then
	    git show $hash
	    echo "Would you like to merge this commit? [Y/n]"
	    read answer
	    if [ -z "$answer" ]; then
		answer="y"
	    fi
	fi
	if [ "$answer" = "y" ]; then
	    git cherry-pick $hash
	    if [ $? = 0 ]; then
		success=`expr $success + 1`
		sed -i -e "/$hash/d" $file
	    else
		#git mergetool
		#if [ $? = 0 ]; then
		#success=`expr $success + 1`
		#    for file in $CHERRY_FILE
		#    do
		#	sed -i -e "/$hash/d" $file
		#    done
		#else
		    git cherry-pick --abort
		#fi
	    fi
	fi
    done
done
done
echo "Complete"
fi

### Diff base branch to auto merged branch ###
########################################### WRITE!!!! #############################################

### Clean up ###
########################################### WRITE!!!! #############################################

echo "All complete"
exit 0
