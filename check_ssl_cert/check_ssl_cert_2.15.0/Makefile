PLUGIN=check_ssl_cert
VERSION=`cat VERSION`
DIST_DIR=$(PLUGIN)-$(VERSION)
DIST_FILES=AUTHORS COPYING ChangeLog INSTALL.md Makefile NEWS README.md VERSION $(PLUGIN) $(PLUGIN).spec COPYRIGHT ${PLUGIN}.1
YEAR=`date +"%Y"`
FORMATTED_FILES=test/unit_tests.sh AUTHORS COPYING ChangeLog INSTALL.md Makefile NEWS README.md VERSION $(PLUGIN) $(PLUGIN).spec COPYRIGHT ${PLUGIN}.1 .github/workflows/* utils/*.sh
SCRIPTS=check_ssl_cert test/*.sh

dist: version_check
	rm -rf $(DIST_DIR) $(DIST_DIR).tar.gz
	mkdir $(DIST_DIR)
	cp -r $(DIST_FILES) $(DIST_DIR)
# avoid to include extended attribute data files
# see https://superuser.com/questions/259703/get-mac-tar-to-stop-putting-filenames-in-tar-archives
	export COPY_EXTENDED_ATTRIBUTES_DISABLE=1; \
	export COPYFILE_DISABLE=1; \
	tar -c -z -f $(DIST_DIR).tar.gz  $(DIST_DIR) && \
	tar -c -j -f $(DIST_DIR).tar.bz2 $(DIST_DIR)

install:
ifndef DESTDIR
	echo "Please define DESTDIR and MANDIR variables with the installation targets"
	echo "e.g, make DESTDIR=/nagios/plugins/dir MANDIR=/nagios/plugins/man/dir install"
else
	mkdir -p $(DESTDIR)
	install -m 755 $(PLUGIN) $(DESTDIR)
	mkdir -p ${MANDIR}/man1
	install -m 644 ${PLUGIN}.1 ${MANDIR}/man1/
endif

version_check:
	grep -q "VERSION\ *=\ *[\'\"]*$(VERSION)" $(PLUGIN)
	grep -q "^%define\ version\ *$(VERSION)" $(PLUGIN).spec
	grep -q -F -- "- $(VERSION)-" $(PLUGIN).spec
	grep -q "\"$(VERSION)\"" $(PLUGIN).1
	grep -q -F "${VERSION}" NEWS
	echo "Version check: OK"

# we check for tabs
# and remove trailing blanks
formatting_check:
	! grep -q '[[:blank:]]$$' $(FORMATTED_FILES)

remove_blanks:
	./utils/format_files.sh $(FORMATTED_FILES)

SHFMT= := $(shell command -v shfmt 2> /dev/null)
format:
ifndef SHFMT
	echo "No shfmt installed"
else
# -p POSIX
# -w write to file
# -s simplify
# -i 4 indent with 4 spaces
	shfmt -p -w -s -i 4 $(SCRIPTS)
endif

clean:
	rm -f *~
	rm -f *.bak
	rm -rf rpmroot

distclean: clean
	rm -rf check_ssl_cert-[0-9]*
	rm -f *.crt
	rm -f *.error

check: test

SHELLCHECK := $(shell command -v shellcheck 2> /dev/null)
SHUNIT := $(shell command -v shunit2 2> /dev/null || if [ -x /usr/share/shunit2/shunit2 ] ; then echo /usr/share/shunit2/shunit2 ; fi )

distcheck: disttest
disttest: dist formatting_check shellcheck
	./utils/check_documentation.sh
	man ./check_ssl_cert.1 > /dev/null

test: disttest
ifndef SHUNIT
	echo "No shUnit2 installed: see README.md"
	exit 1
else
	( export SHUNIT2=$(SHUNIT) && export LC_ALL=C && cd test && ./unit_tests.sh )
endif


shellcheck:
ifndef SHELLCHECK
	echo "No shellcheck installed: skipping check"
else
	if shellcheck --help 2>&1 | grep -q -- '-o\ ' ; then shellcheck -o all $(SCRIPTS) ; else shellcheck $(SCRIPTS) ; fi
endif

rpm: dist
	mkdir -p rpmroot/SOURCES rpmroot/BUILD
	cp $(DIST_DIR).tar.gz rpmroot/SOURCES
	rpmbuild --define "_topdir `pwd`/rpmroot" -ba check_ssl_cert.spec



.PHONY: install clean test rpm distclean check
