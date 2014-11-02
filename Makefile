
all: run

client.js:
	cd client && make all

ssr.js: client.js
	cp ./client/result/client.js ./server/resources/js/ssr.js

server.unix:
	cd server && mirage configure --unix && make

unix: server.unix ssr.js

run: unix
	./server/mir-ssr

clean:
	rm -f server/resources/js/ssr.js
	cd server && make clean
	cd client && make clean

distclean: clean
	cd server && mirage clean
	cd client && make distclean && oasis setup-clean

.PHONY: run clean distclean client.js
