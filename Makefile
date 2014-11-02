
all: run

client:
	cd client && make all && cp ./result/client.js ../server/resources/js/ssr.js

server-unix:
	cd server && mirage configure --unix && make

unix: client server-unix

run: unix
	./server/mir-ssr

clean:
	rm -f server/resources/js/ssr.js
	cd server && make clean
	cd client && make clean

distclean: clean
	cd server && mirage clean
	cd client && make distclean && oasis setup-clean

.PHONY: run clean distclean client unix server-unix
