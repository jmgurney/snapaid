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

BEGIN {
	vmroot = "https://download.freebsd.org/ftp/snapshots/VM-IMAGES/"
	isoroot = "https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/"
}

tolower($1) == "message-id:" {
	MID=$2
	sub(".*<", "", MID)
	sub(">.*", "", MID)
}

$0 == "== ISO CHECKSUMS ==" {
	root = isoroot
	type = "iso"
}

$0 == "== VM IMAGE CHECKSUMS ==" {
	root = vmroot
	type = "vm"
}

function isdate(date) {
	m = match(date, "[0-9]+")
	if (m && RLENGTH == 8)
		return 1

	return 0
}

#FreeBSD-13.0-CURRENT-powerpc-powerpcspe-20181026-r339752-bootonly.iso
#FreeBSD-13.0-CURRENT-sparc64-20181026-r339752-bootonly.iso.asc
#FreeBSD-13.0-CURRENT-arm64-aarch64-PINE64-LTS-20181026-r339752.img.xz
#FreeBSD-13.0-CURRENT-i386-20181026-r339752.vmdk.xz

$1 == "SHA512" {
	# Strip parens
	fname = substr($2, 2, length($2) - 2)

	split(fname, dotparts, ".")

	# recombine around version string, strips of ALL extensions (including vm type)
	basename = dotparts[1] "." dotparts[2]

	cnt = split(basename, parts, "-")

	# make arch part, may include additional part
	arch = parts[4]
	basearch = arch
	if (parts[4] == "arm" || (parts[4] == "powerpc" && parts[5] == "powerpcspe") || parts[4] == "arm64") {
		basearch = parts[5]
		arch = parts[4] "-" parts[5]
		nextidx = 6
	} else
		nextidx = 5

	# find date, may be platform first
	if (isdate(parts[nextidx])) {
		platform = "xxx"
		date = parts[nextidx]
		nextidx += 1
	} else {
		platform = parts[nextidx]
		date = parts[nextidx + 1]
		if (isdate(date)) {
			nextidx += 2
		} else {
			date = parts[nextidx + 2]
			platform = parts[nextidx] "-" parts[nextidx + 1]
			nextidx += 3
		}
	}

	if (nextidx == cnt)
		vers="xxx"
	else {
		vers=""
		sep=""
		for (i = nextidx + 1; i <= cnt; i++) {
			vers = vers sep parts[i]
			sep="-"
		}
	}
	if (type == "vm") {
		vers = dotparts[3]
		url = root parts[2] "-" parts[3] "/" basearch "/" date "/" fname
	} else
		url = root parts[2] "/" fname

	# if this part doesn't begin w/ r (for svn rev), skip it, we can't parse
	# others for now
	if (substr(parts[nextidx], 1, 1) != "r")
		next

	# double check that date is valid, if not, skip it
	if (!isdate(date))
		next

	printf("%s %s %s %s %s %s %s %s %s %s\n", type, parts[2] "-" parts[3], arch, platform, date, parts[nextidx], vers, fname, url, MID)
}
