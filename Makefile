test:
	(ls mksnapidx.awk fixtures/*) | entr sh -c 'set -e; for i in fixtures/*.txt; do awk -f mksnapidx.awk "$$i" > "$${i%.txt}".test.out; cmp "$${i%.txt}".test.out "$${i%txt}snapidx.out"; echo "$$i ok"; done'
