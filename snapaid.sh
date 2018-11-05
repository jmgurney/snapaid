#!/bin/sh -

STOREDIR="$HOME/.snapaid"
KEYS="0x524F0C37A0B946A3"
KEY_URLS='https://svnweb.freebsd.org/doc/head/share/pgpkeys/gjb.key?view=co'

setdefaults() {
	GPG=$(which gpg2)
	WGET=$(which wget)
	SHASUM=$(which shasum)
}
setdefaults

if [ ! -x "$GPG" ]; then
	echo 'Failed to find gpg2 executable'
	exit 1
fi

if [ ! -x "$WGET" ]; then
	echo 'Failed to find wget executable'
	exit 1
fi

if [ ! -x "$SHASUM" ]; then
	echo 'Failed to find shasum executable'
	exit 1
fi

#wget:
# -N for timestamps
# --backups=x for backing up
hostname=people.FreeBSD.org
completeurl="https://${hostname}/~jmg/FreeBSD-snap/snapshot.complete.idx.xz"
currenturl="https://${hostname}/~jmg/FreeBSD-snap/snapshot.idx.xz"

# type release arch platform date svnrev xxx fname url mid
# 1    2       3    4        5    6      7   8     9   10
# iso 11.1-STABLE arm-armv6 BEAGLEBONE 20180315 r330998 xxx FreeBSD-11.1-STABLE-arm-armv6-BEAGLEBONE-20180315-r330998.img.xz https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/11.1/FreeBSD-11.1-STABLE-arm-armv6-BEAGLEBONE-20180315-r330998.img.xz 20180316000842.GA7399@FreeBSD.org

set -e

# This is used for some testing functions
copy_function() {
  declare -F "$1" > /dev/null || return 1
  local func="$(declare -f "$1")"
  eval "${2}(${func#*\(}"
}

# Test function to cause a bad input
cmd_failure() {
	exit 1
}

# First time fails, second time run real command
gpg_first_fails() {
	copy_function verifygpg_orig verifygpg
	return 1
}

# When first arg is --, just touch the file to fake a bad d/l
bad_file_dl() {
	if [ x"$1" = x"--" ]; then
		touch $(basename "$2")
	else
		$WGET_orig "$@"
	fi
}

# Make sure that the storage directory is present
mkstore() {
	mkdir "$STOREDIR" 2>/dev/null || :
	if ! [ -x "$STOREDIR" -a -w "$STOREDIR" -a -d "$STOREDIR" ]; then
		echo "$STOREDIR is not a writable directory."
	fi
}

check_keys() {
	for i in $KEYS; do
		if ! $GPG --list-keys "$i" >/dev/null 2>&1; then
			return 1
		fi
	done

	return 0
}

# Given a message id, get the raw body and store it.
get_raw() {
	mkstore

	mid="$1"

	midfile="$STOREDIR/$mid".raw

	if [ ! -e "$midfile" ]; then
		# get the location, it's a database lookup
		loc=$($WGET --max-redirect=0 --method=HEAD -S -o - -O - 'https://docs.freebsd.org/cgi/mid.cgi?'"$mid" 2>/dev/null | awk 'tolower($1) == "location:" { print $2; exit }')

		# Some emails are sent to both -current and -snapshot,
		# we can't handle them for now
		# such as 20160529215940.GA11785@FreeBSD.org
		if [ x"$loc" = x"" ]; then
			return 1
		fi

		# if it's relative, add https
		if [ x"$loc" != x"${loc#//}" ]; then
			# add https
			loc="https:$loc"
		fi

		# get the raw part
		tmpfile="$STOREDIR/.tmp.$$.$mid".raw

		# strip out everything but message id and first signed part
		$WGET -O - "$loc"+raw 2>/dev/null | awk '
			tolower($1) == "message-id:" && check == 0 {
				print
			}

			$0 == "-----BEGIN PGP SIGNED MESSAGE-----" {
				sigbody = 1
			}

			sigbody {
				print
			}

			$0 == "-----END PGP SIGNATURE-----" {
				sigbody = 0
			}' > "$tmpfile"

		if verifygpg "$tmpfile"; then
			mv "$tmpfile" "$STOREDIR/$mid.raw"
		else
			rm "$tmpfile"
			echo Bad signature from mail archive.
			return 1
		fi
	else
		if ! verifygpg "$midfile"; then
			rm "$midfile"
			get_raw "$mid"
			return $?
		fi
	fi
}

fetch() {
	mkstore

	if ! (cd "$STOREDIR" && $WGET -N "$1" >/dev/null 2>&1); then
		return 1
	fi
}

getvermid() {
	xzcat "$STOREDIR"/snapshot.complete.idx.xz | awk '$8 == fname {
	print $10
}' fname="$i"

}

# takes basename of arg, which much exist in STOREDIR, and verifies
# that the signature is valid.
verifygpg() {
	local fname
	fname=$(basename "$1")
	if ! (cd "$STOREDIR" && $GPG --verify "$fname" 2> /dev/null); then
		echo 'ERROR: PGP signature verification failed!'
		return 1
	fi
}

# Verifies the file
verifyfile() {
	local fname
	local hashinfo
	local algo hash

	fname="$STOREDIR/${1}.raw"
	hashinfo=$(awk '
		check && $2 == "('"$2"')" {
			hashes[$1] = $4
		}

		$0 == "-----BEGIN PGP SIGNED MESSAGE-----" {
			check = 1
		}

		$0 == "-----BEGIN PGP SIGNATURE-----" {
			check = 0
		}

		END {
			if ("SHA512" in hashes)
				algo = "SHA512"
			else if ("SHA256" in hashes)
				algo = "SHA256"
			else {
				print "unkn BADHASH"
				exit 1
			}

			print algo " " hashes[algo]
		}
		' "$fname")
	read algo hash <<-EOF
		${hashinfo}
EOF

	if [ x"$algo" == x"unkn" -o x"$algo" = x"" ]; then
		echo 'Unable to find hash for file.'
		exit 1
	fi

	echo "$hash  $2" | $SHASUM -a "${algo#SHA}" -c -
}

dlverify() {
	fname="$8"
	dlurl="$9"
	vermid="${10}"

	# verify snap email
	if ! get_raw "$vermid"; then
		echo "Unable to fetch/verify snapshot email for: $fname"
		return 1
	fi

	# fetch link
	$WGET -- "$dlurl"

	if ! verifyfile "$vermid" "$fname"; then
		echo 'Removing bad file.'
		rm "$fname"
		return 1
	fi
}

if ! check_keys; then
	echo 'Necessary keys have not been imported into key ring.'
	echo "Please obtain they following keyid(s):"
	echo $KEYS
	echo ""
	echo "The keys may be obtained from the following URLs:"
	for i in $KEY_URLS; do
		echo "$i"
	done
	echo ""
	echo "and imported into GPG w/ the --import option."
	echo ""
	echo "For extra security, additional verification should be done, such"
	echo "as manually verifying finger prints."

	exit 3
fi

if [ x"$1" = x"verify" ]; then
	shift

	if ! fetch "$completeurl"; then
		echo Failed to fetch the complete index.
		exit 1
	fi

	for i in "$@"; do
		vermid=$(getvermid "$i")
		if [ x"$vermid" = x"" ]; then
			echo "Unable to find entry for: $i"
			continue
		fi

		if ! get_raw "$vermid"; then
			echo "Unable to fetch snapshot email for: $i"
			continue
		fi

		verifyfile "$vermid" "$i"
	done
elif [ x"$1" = x"find" ]; then
	fetch "$currenturl"

	tmpdir=$(mktemp -d -t snapaid)

	trap "rm -rf $tmpdir" 0

	( cd "$tmpdir";
	xzcat "$STOREDIR"/snapshot.idx.xz | sort -r -k 5 > selection;
	while :; do
		# display current list
		cnt=$(wc -l < selection)
		awk '
BEGIN {
	fmtstr = "%2s %-3s  %-15s %-18s %-18s %-8s %-7s\n"
	printf(fmtstr, "#", "TYP", "RELEASE", "ARCH", "PLATFORM/TYPE", "DATE", "SVNREV")
	cnt = 1
}

{
	if ($4 == "xxx")
		plt=$7
	else
		plt=$4
	printf(fmtstr, cnt, $1, $2, $3, plt, $5, $6)
	if (cnt >= 20)
		exit 0

	cnt += 1
}
		' selection

		read -p 'Select image #, enter search term, reset, or quit: ' sel
		if [ x"$sel" = x"reset" ]; then
			xzcat "$STOREDIR"/snapshot.idx.xz | sort -r -k 5 > selection;
			continue
		elif [ x"$sel" = x"quit" ]; then
			echo "$sel" > sel
			break
		fi

		if [ "$cnt" -gt 20 ]; then
			cnt=20
		fi

		if [ "$sel" -ge 1 -a "$sel" -le "$cnt" ] 2>/dev/null; then
			echo $(tail -n +"$sel" selection | head -n 1) > sel
			break
		else
			# restrict

			if ! grep -- "$sel" selection > selection.new; then
				echo WARNING: Ignoring selection, no results.
			else
				mv selection.new selection
			fi
		fi
	done
	)

	sel=$(cat "$tmpdir"/sel)
	if [ x"$sel" = x"quit" ]; then
		exit 0
	fi

	set -- ${sel}

	echo selected image "$8"

	dlverify ${sel}
elif [ x"$1" = x"test" ]; then
	# Setup test environment
	tmpdir=$(mktemp -d -t snapaid)

	trap "rm -rf $tmpdir" 0

	cd "$tmpdir"

	STOREDIR="$tmpdir"/snapaid

	# Make sure that the check keys function works.
	echo 'Testing check_keys works...'

	# Prime the custom keyring
	GPG="gpg2 --no-default-keyring --keyring pubring.gpg"
	for i in $KEY_URLS; do
		$WGET -O - -- "$i" 2>/dev/null | $GPG --import 2>/dev/null
	done

	if ! check_keys; then
		echo failed
		exit 1
	fi

	KEYS_orig="$KEYS"
	KEYS="0x1384923867573928" # bogus key

	if check_keys; then
		echo failed
		exit 1
	fi

	echo passed

	# Test a bad download fails
	echo 'Testing dlverify...'
	WGET_orig="$WGET"
	WGET=bad_file_dl

	# if dlverify is successsful, then it's a failure
	if dlverify iso 13.0-CURRENT sparc64 xxx 20181026 r339752 bootonly FreeBSD-13.0-CURRENT-sparc64-20181026-r339752-bootonly.iso.xz https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/13.0/FreeBSD-13.0-CURRENT-sparc64-20181026-r339752-bootonly.iso.xz 20181026184443.GD75350@FreeBSD.org; then
		echo 'failed'
		exit 1
	fi

	# Make sure that a bad d/l was not left behind
	if [ -e FreeBSD-13.0-CURRENT-sparc64-20181026-r339752-bootonly.iso.xz ]; then
		echo failed
		exit 1
	fi
	echo passed

	# Test getting the raw file
	echo 'Testing get_raw success...'
	mid='20160122055622.GA87581@FreeBSD.org'
	get_raw "$mid"

	# Verify resulsts
	(cd "$STOREDIR" && echo '6e53df5995b6cc423c7f2d63b6df52d5d7f70e8586c25f91433fd8a1a2466e77be6a38884bde8bedd9ff6e7deb0215a66e1c2a16e4955503c20445e649a5fb47  20160122055622.GA87581@FreeBSD.org.raw' | $SHASUM -a 512 -c)
	echo passed

	# If the file already exists, but fails verification, that
	# it will refetch and be correct
	echo 'Testing get_raw with file already present that fails verification...'
	copy_function verifygpg verifygpg_orig
	copy_function gpg_first_fails verifygpg
	get_raw "$mid"

	(cd "$STOREDIR" && echo '6e53df5995b6cc423c7f2d63b6df52d5d7f70e8586c25f91433fd8a1a2466e77be6a38884bde8bedd9ff6e7deb0215a66e1c2a16e4955503c20445e649a5fb47  20160122055622.GA87581@FreeBSD.org.raw' | $SHASUM -a 512 -c)

	echo passed

	# If the file already exists, a "broken" wget won't cause
	# a problem
	echo 'Testing get_raw with file already present...'
	WGET=cmd_failure
	get_raw "$mid"

	echo passed

	# Test failure
	echo 'Testing get_raw fails w/ bad data...'
	WGET=cmd_failure
	rm "$STOREDIR/$mid.raw"

	# it should fail
	! get_raw "$mid"

	# and the desired file should not exist
	if [ -e "$STOREDIR/$mid.raw" ]; then
		echo 'Test failed!'
		exit 1;
	fi
	echo passed

	setdefaults

	echo tests completed!!!
else
	echo "Unknown verb: $1"
	echo "Usage:"
	echo "	$0 verify file ..."
	echo "	$0 find"
	echo ""
	echo "The verify option will attempt to verify each file specified."
	echo ""
	echo "The find option will start up an interactive session to find"
	echo "and select the snapshot to download and verify."
fi
