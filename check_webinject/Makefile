PLUGIN := tmp/check_webinject

include ../common.mk

tmp/check_webinject:
	mkdir -p tmp
	sed -e '/^package Web/,/^#!\/usr\/bin\/env perl/d' \
	    -e '/^my.*Webinject->/ iuse Webinject;\n' \
	    check_webinject > $@

clean::
	rm -rf tmp

