import itertools
import mailbox
import sys

if __name__ == '__main__':
	cnt = itertools.count()
	mb = mailbox.mbox(sys.argv[1])
	for i in mb.itervalues():
		body = i.get_payload()
		if isinstance(body, list):
			continue
		with open('%s%04d' % (sys.argv[2], cnt.next()), 'w') as fp:
			print >>fp, 'Message-ID:', i['message-id']
			fp.write(body)
