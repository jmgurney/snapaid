#!/bin/sh -

set -e

args=`getopt m $*`
if [ $? -ne 0 ]; then
	echo 'Usage: $0 [ -m ]'
	exit 2
fi
set -- $args
while :; do
	case "$1" in
	-m)
		more=1
		shift
		;;
	--)
		shift; break
		;;
	esac
done

mkdir "$0.running"

# minimize file
tmpfname="tmp.snapinf.asc"
awk '
	output != 1 && tolower($1) == "message-id:" {
		print
		next
	}

	$0 == "-----BEGIN PGP SIGNED MESSAGE-----" {
		output = 1
	}

	output == 1 {
		print
	}

	$0 == "-----END PGP SIGNATURE-----" {
		output = 0
	}' > "$tmpfname"

if ! gpg --verify "$tmpfname"; then
	echo 'failed verify'
	rm "$tmpfname"
	rmdir "$0.running"
	exit 1
fi

# process file
awk -f ./mksnapidx.awk "$tmpfname" > additional
rm "$tmpfname"

# only check if there isn't more to come
if [ x"$more" = x"1" ]; then
	(cat snapshot.idx || :; cat additional) > snapshot.idx.new
	(cat snapshot.complete.idx || :; cat additional) > snapshot.complete.idx.new
else
	(xzcat snapshot.idx.xz; cat additional) | sort -u | awk '
	{
		if (!system("wget --method=HEAD " $9))
			print
	}
	' > snapshot.idx.new

	xz snapshot.idx.new

	(xzcat snapshot.complete.idx.xz || :; cat additional) | sort -u > snapshot.complete.idx.new
	xz snapshot.complete.idx.new
fi

rm additional

# install new indexes
if [ x"$more" = x"1" ]; then
	mv snapshot.idx.new snapshot.idx
	mv snapshot.complete.idx.new snapshot.complete.idx
else
	mv snapshot.idx.new.xz snapshot.idx.xz
	mv snapshot.complete.idx.new.xz snapshot.complete.idx.xz
fi

rmdir "$0.running"
