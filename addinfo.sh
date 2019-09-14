#!/bin/sh -
#
# Copyright 2018 John-Mark Gurney.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
#	$Id$
#

set -e

usage() {
	echo "Usage: $0 [ -m ] <file>"
	echo "Usage: $0 -c <date>"
	echo ''
	echo 'date is specified as YYYYMMDD'

	if [ x"$1" != x"" ]; then
		exit $1
	fi
}

args=`getopt cm $*`
if [ $? -ne 0 ]; then
	usage 2
fi
set -- $args
while :; do
	case "$1" in
	-c)
		complete=1
		shift
		;;
	-m)
		more=1
		shift
		;;
	--)
		shift; break
		;;
	esac
done
if [ x"$complete" = x"1" -a x"$more" = x"1" ]; then
	echo '-m and -c cannot be specified at the same time.'
	usage 2
elif [ x"$complete" = x"1" -a $# -ne 1 ]; then
	echo 'must only specify a date with -c'
	usage 2
elif [ x"$complete" != x"1" -a $# -ne 1 ]; then
	echo 'must specify exactly one file'
	usage 2
fi

mkdir "$0.running"

if [ x"$complete" = x"1" ]; then
	sort -u snapshot.complete.idx | xz > snapshot.complete.idx.xz
	awk '$5 >= "'"$1"'" { 
			if (!system("wget --method=HEAD " $9))
				print
		}
		' snapshot.idx | sort -u | xz > snapshot.idx.xz
	rm snapshot.idx snapshot.complete.idx
	rmdir "$0.running"
	exit 0
fi

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
	}' "$1" > "$tmpfname"

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
