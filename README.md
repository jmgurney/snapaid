snapaid
=======

This is a utility that will make it easier to find and download the
correct snapshot.  It will also fetch and verify the GPG signature
and hash of the snapshot to ensure that you are getting the correct
file.

![Screen shot of snapaid.sh find](images/snapaid.find.png?raw=true)

Quick Start
-------------

The only file needed for this is the snapaid.sh script.  The other files
are used for generating the index.

```
$wget https://raw.githubusercontent.com/jmgurney/snapaid/master/snapaid.sh
$chmod 755 snapaid.sh
$./snapaid.sh find
```

Notes
-----

This repository will be signed by my FreeBSD GPG key.  It is available
at: [https://www.freebsd.org/doc/en_US.ISO8859-1/articles/pgpkeys/pgpkeys-developers.html]

You will *NOT* see the verified tag on github, because if I upload my key
to github, github will mark edits done on the website as verified even
though it was not authenticated by my GPG key.  This destroys the point
of signing commits, as anyone who is able to take over my github account
and not my GPG key, could now impersonate me, and make malicious changes.

NOTE: The xz vs non-xz versions of some of the images are not able to be
differentiated.  Currently shorting rules should always put the xz version
before the non-xz version.

NOTE: Only snapshots that have SHA512 hashes are included.  This excludes
most snapshots from 2015 and before.  The tool could be updated to include
SHA256, but not a priority currently.

NOTE: Not all of the snapshots are in the database.  Some snapshot names,
like 11.0-RC1, don't contain all the info others do, and are not
included.  In the future, hopefully this will be fixed.

backend
-------

The backend is just a simple text file the indexes all the published
snapshots.  It is built from the emails to the freebsd-snapshot
list.  After verification of the email's signature, the SHA512 entry
lines are extracted, the file name is parsed, and added to the complete
index.  The message-id of the email is in the index so that the frontend
can d/l the original email, verify the GPG signature locally.  The
complete index is used for verifying a snapshot that has already been
downloaded.  Another index is also maintained which only contains the
currently available to d/l snapshots.
