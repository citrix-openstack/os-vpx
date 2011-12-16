#!/bin/sh

set -eu

# Check that we pass the right number of arguments
if [ "$#" -lt 2 ] 
then
  echo
  echo "Usage: $0 <Path to Remote Launchpad Branch> <Path to upstream directory for Local Mercurial Repository>"
  echo
  echo "Example: sh rebase.sh lp:nova NOVA_HG_HOME/upstream"
  echo "         where NOVA_HG_HOME is the root of your nova.hg repository"
  echo
  echo "You can also rebase automatically from your [ nova | glance | swift ].hg repository with <make rebase>"
  echo
  exit 1
fi

# Check that the upstream directory exists
if [ ! -e "$2" ]
then
  echo "Upstream directory $2 does not exist, bailing!"
  exit 1
fi

# Check that the Launchpad repository exists
echo "Checking branch: $1"
bzr info "$1"

# Get on, and do the rebase
branch="$1"
dest="$2"

rebasedir="/tmp/rebase"
tempdir=$(mktemp -d -u --tmpdir="$rebasedir")

cleanup()
{
  rm -rf "$tempdir"
}
trap cleanup EXIT

if [ ! -d "$rebasedir" ]
then
    mkdir -p "$rebasedir"
    bzr init-repo "$rebasedir"
fi

(cd "$rebasedir"
 bzr branch "$branch" $(basename "$tempdir"))

revno=$(cd "$tempdir"; bzr revno)
msg="Rebased to $branch revision $revno."

rsync -a --delete "$tempdir/" "$dest/"
find "$dest" -name .bzr | xargs rm -r

echo "$msg"
echo
echo "You might want:"
echo "hg commit -A upstream -m '$msg'"
echo
echo "Before pushing the changeset to the remote repository, bear in mind that"
echo "the following items might break the build:"
echo
echo " - changes to config files"
echo " - added/removed bin files"
echo " - added/removed xapi.d plugin files"
echo " - sed commands in the rpm spec"
echo " - patch commands in the rpm spec"
echo 
echo "Also, beware of python packages upgrades. You can find references in the"
echo "easy-install configuration file."
echo
echo "If you find that something else has broken the build, please document it here!"
echo
