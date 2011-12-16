#!/bin/sh

usage()
{
  echo "$0 --output=<directory> --vendor-code=<vendor code> --vendor-name=<vendor name> --label=l --text=t --version=v [--build=b] [--repo-data=file] [--mem=val] [--homogeneous] [--no-iso] [--tarball] [--reorder] package_files" >&2
  exit 1
}

die()
{
  echo "$*" >&2
  exit 1
}

reorder()
{
  local rpmout
  local rpm

  rpmout=/tmp/rpm.$$

  rpm -ivv --test --nosignature $@ >$rpmout 2>&1

  sed -ne 's/$/.rpm/; /tsorting packages/,$ s/^D:\( *[0-9-]\)\+ *+//p' $rpmout | while read rpm
  do
    sed -ne "s+.*== \([^ ]*$rpm\)$+\1+p" $rpmout
  done

  rm -f $rpmout
}

verify_driver_rpm()
{
  local rpm=$1
  local label=$2
  local kernel=$3
  local ret=0
  local f

  # check paths of files in playload
  for f in `rpm --nosignature -qlp $rpm`; do
    local reject=0
    case "$f" in
      /lib/modules/$kernel/extra/*)
        :;;
      /etc/udev/rules.d/*)
        [ "$kernel" = any ] || reject=1;;
      /lib/firmware/*)
        [ "$kernel" = any ] || reject=1;;
      /etc/*)
        [ "$kernel" = any ] || reject=1;;
      /usr/share/doc/*)
        [ "$kernel" = any ] || reject=1;;
      *)
        echo "Error: unsupported file $f in $rpm" >&2
        ret=1;;
    esac
    if [ $reject -eq 1 ]; then
       echo "Error: unsupported file $f in $rpm" >&2
      ret=1
    fi
  done

  case "$kernel" in
    any)
      :;;
    *xen)
      xen_list="$xen_list $label:`basename $kernel xen`";;
    *kdump)
      kdump_list="$kdump_list $label:`basename $kernel kdump`";;
    *)
      echo "Error: unexpected kernel suffix ($kernel)" >&2
      ret=1;;
  esac

  return $ret
}

verify_user_rpm()
{
  local rpm=$1
  local ret=0
  local f

  # check paths of files in playload
  for f in `rpm --nosignature -qlp $rpm`; do
    case "$f" in
      /lib/modules/*)
        echo "Error: unsupported file $f in $rpm" >&2
        ret=1;;
      /boot/vmlinu*)
        echo "Error: unsupported file $f in $rpm" >&2
        ret=1;;
    esac
  done

  return $ret
}


reorder=1

while [ -n "$1" ]; do
  case "$1" in
    --output=*)
      output=${1#--output=};;
    --vendor-code=*)
      vendor_code=${1#--vendor-code=};;
    --vendor-name=*)
      vendor_name=${1#--vendor-name=};;
    --label=*)
      package_label=${1#--label=};;
    --text=*)
      text=${1#--text=};;
    --version=*)
      version=${1#--version=};;
    --build=*)
      build=${1#--build=};;
    --repo-data=*)
      repo_data=${1#--repo-data=};;
    --mem=*)
      mem=${1#--mem=};;
    --homogeneous)
      homogeneous=1;;
    --no-iso)
      noiso=1;;
    --tarball)
      tarball=1;;
    --reorder)
      reorder=1;;
    --noreorder)
      reorder=0;;
    -*)
      usage;;
    *)
      break;
  esac
  shift
done

[ -n "$output" ] || usage
[ -n "$vendor_code" ] || usage
[ -n "$vendor_name" ] || usage
[ -n "$package_label" ] || usage
[ -n "$text" ] || usage
[ -n "$version" ] || usage
[ -n "$repo_data" -a ! -r "$repo_data" ] && die "Cannot open repo data"

if [ $reorder -eq 1 ]; then
  echo "Reordering packages..."
  packages=`reorder $*`
else
  packages=$*
fi

pkg=XS-PACKAGES
repo=XS-REPOSITORY

thisdir=$(dirname "$0")
install_sh="$thisdir/suppack-install.sh"
if [ ! -f "$install_sh" ]
then
  die "Cannot find suppack-install.sh"
fi
uninstall_sh="$thisdir/suppack-uninstall.sh"
if [ ! -f "$uninstall_sh" ]
then
  die "Cannot find suppack-uninstall.sh"
fi

echo "<packages>" >$pkg

for f in $packages; do
  set -- `wc -c $f`
  size=$1
  set -- `md5sum $f`
  md5=$1
  case `file -k -b $f` in
    *bzip2*)
      label=`basename $f .tar.bz2`
      echo "<package label=\"$label\" type=\"tbz2\" size=\"$size\" md5=\"$md5\" root=\"/\">$f</package>" >>$pkg;;
    *RPM*)
      group=`rpm --nosignature -q --qf '%{GROUP}' -p $f`
      case "$group" in
	*/Kernel)
          set -- `rpm --nosignature -q --qf '%{NAME}' -p $f | sed -e 's/\(.*\)-modules-\([^-]*\)-\(.*\)/\1 \3\2/'`
          label="$1"
          kernel="$2"
	  [ -z "$kernel" ] && kernel=any
	  verify_driver_rpm $f $label $kernel || exit 1
          echo "<package label=\"$label\" type=\"driver-rpm\" kernel=\"$kernel\" size=\"$size\" md5=\"$md5\">$f</package>" >>$pkg;;
	*)
	  label=`rpm --nosignature -q --qf '%{NAME}' -p $f`
	  verify_user_rpm $f || exit 1
          echo "<package label=\"$label\" type=\"rpm\" size=\"$size\" md5=\"$md5\">$f</package>" >>$pkg;;
      esac;;
    *)
      echo "Error: unknown package type $f" >&2
      exit 2;;
  esac
done

echo "</packages>" >>$pkg

# check for pairs of drivers
for x in $xen_list; do
  found=0
  for k in $kdump_list; do
    [ "$x" = "$k" ] && found=1 && break
  done
  if [ $found -eq 0 ]; then
    echo "Error: no kdump kernel module found for $x" >&2
    exit 2
  fi
done
for k in $kdump_list; do
  found=0
  for x in $xen_list; do
    [ "$x" = "$k" ] && found=1 && break
  done
  if [ $found -eq 0 ]; then
    echo "Error: no xen kernel module found for $k" >&2
    exit 2
  fi
done

[ -n "$build" ] && build_text=" build=\"$build\""
[ -n "$mem" ] && mem_text=" memory-requirement-mb=\"$mem\""
[ -n "$homogeneous" ] && hom_text=" enforce-homogeneity=\"true\""
cat >$repo <<EOF
<repository originator="$vendor_code" name="$package_label" product="XenServer" version="$version"$build_text$mem_text$hom_text>
<description>$text</description>
<requires originator="xs" name="main" test="ge" product="XenServer" version="6.0.0" />
EOF

[ -n "$repo_data" ] && cat $repo_data >>$repo
echo "</repository>" >>$repo

cp -fp "$install_sh" install.sh
chmod +x install.sh
cp -fp "$uninstall_sh" uninstall.sh
chmod +x uninstall.sh

cat $repo $pkg | md5sum | tr -d ' -' >"$output/$package_label.metadata.md5"
tar -czf "$output/$package_label.tar.gz" .
if [ -z "$noiso" ]
then
  mkisofs -A "$vendor_name" -V "$text" -J -joliet-long -r -o "$output/$package_label.iso" .
  cd "$output" && md5sum "$package_label.iso" >"$package_label.iso.md5"
fi
if [ -z "$tarball" ]
then
  rm "$output/$package_label.tar.gz"
fi
