#/usr/bin/make -f
CLEANFILES = check_memcached check_memcached.c
LIBS += -lmemcached

include ../common.mk


check_memcached: check_memcached.o
	$(CC) $(LDFLAGS) -o $@ $< $(LIBS)
