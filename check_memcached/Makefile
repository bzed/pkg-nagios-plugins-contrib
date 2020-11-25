#/usr/bin/make -f
CLEANFILES = check_memcached check_memcached.c
PKG_CONFIG ?= pkg-config
LIBS += $(shell $(PKG_CONFIG) --libs libmemcached) -lpthread

include ../common.mk


check_memcached: check_memcached.o
	$(CC) $(LDFLAGS) -o $@ $< $(LIBS)
