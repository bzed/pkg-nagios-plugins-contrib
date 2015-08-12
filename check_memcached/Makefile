#/usr/bin/make -f
CLEANFILES = check_memcached check_memcached.c
LIBS += $(shell pkg-config --libs libmemcached) -lpthread

include ../common.mk


check_memcached: check_memcached.o
	$(CC) $(LDFLAGS) -o $@ $< $(LIBS)
