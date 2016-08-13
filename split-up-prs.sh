#!/bin/bash
#
# This will submit all your changes in a separate PR for each file.
#
# Warning:
# --------
# This is in an alpha version. Make a backup of your changes and use only if you
# have a decent experience with git

PREFIX=""				# prefix tag to use for commit and PR message
SIMULATE=1 				# only show which files would be submitted
STEP_BY_STEP=1 			# only submit on PR per run

# for debugging:
#set -uexo

echo "Warning. This tool is in alpha-phase and should be used with great care".

# parse all options
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--prefix)
    	PREFIX="$2"
    	shift
    ;;
    -f|--simulate)
    	SIMULATE=0
    	echo "Warning: you are now ending the simulation and working with real files."
    ;;
    -a|--all)
    	STEP_BY_STEP=0
    ;;
    *)
    	echo "$key is unknown"
    	exit 1
    ;;
esac
shift # past argument or value
done

if [ -z "$PREFIX" ] ; then
	echo "Requires a prefix to be set (e.g. [german]). Use -p/--prefix".
	exit 1
fi

# unstages everything, so we can start from scratch
git reset master

files=$(git status --porcelain | cut -c4- | tr '\n' ' ')

# using the CLI tool hub is the most convenient option, otherwise we will show a URL
hubInstalled=$(which $program 2>/dev/null | grep -v "not found" | wc -l)
if [ ! $hubInstalled ] ; then
	# gets your github username, might not work on every platform
	gitUser=$(git remote -v | grep origin | head | sed -E 's!.*github.com:+/+(.*)/dlang-tour.*$!\1!')
fi

for filename in $files ; do
	# for simplicity skip index.yml an
	if [ $(basename "$filename") == "index.yml" ] ; then
		continue
	fi
	# ignore other unrelated changes
	if ! grep -q "public\/content\/.*" <<< "$filename" ; then
		continue
	fi

	echo "Adding: $filename"

	if [ $SIMULATE -eq 1 ] ; then
		continue
	fi
	git checkout master

	shortFileName=$(echo "$filename" | sed 's!public/content/!!')
	# defensive removal of existing branches, it won't remove unmerged branches!
	gb -d "$shortFileName" 2> /dev/null || true
	git checkout -b $shortFileName
	git add "$filename"

	# commit & submit
	commitMessage="${PREFIX} ${shortFileName}"
	git commit -m "$commitMessage"
	git push --set-upstream origin $shortFileName

	if [ $hubInstalled ] ; then
		hub pull-request -m "$commitMessage"
	else
		# this should be cross-platform, but it's not tested
		xdg-open "https://github.com/stonemaster/dlang-tour/compare/master...$gitUser:$shortFileName"
	fi

	if [ $STEP_BY_STEP ] ; then
		echo "step-by-step executing is activated. use -a/--all to run for all remaining."
		exit
	fi
done

git checkout master

if [ $SIMULATE -eq 1 ] ; then
	echo "Simulation was run. Now use -f/--force to apply."
fi
