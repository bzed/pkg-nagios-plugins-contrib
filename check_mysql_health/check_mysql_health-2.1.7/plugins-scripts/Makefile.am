## Process this file with automake to produce Makefile.in

SUFFIXES = .pl .pm .sh

VPATH=$(top_srcdir) $(top_srcdir)/plugins-scripts $(top_srcdir)/plugins-scripts/t

libexec_SCRIPTS=check_mysql_health
MY_MODULES=
EXTRA_MODULES=\
  Nagios/DBD/MySQL/Server/Instance/Innodb.pm \
  Nagios/DBD/MySQL/Server/Instance/Myisam.pm \
  Nagios/DBD/MySQL/Server/Instance/Replication.pm \
  Nagios/DBD/MySQL/Server/Instance.pm \
  Nagios/DBD/MySQL/Server.pm \
  Nagios/DBD/MySQL/Cluster.pm \
  Nagios/Extraopts.pm
EXTRA_DIST=check_mysql_health.pl $(EXTRA_MODULES)

CLEANFILES=$(libexec_SCRIPTS)

AM_INSTALL_PROGRAM_FLAGS=@INSTALL_OPTS@

.pm :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.pl :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.sh :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

$(libexec_SCRIPTS) : $(EXTRA_DIST)
	$(ECHO) "#! #PERL# -w" | $(AWK) -f ./subst > $@
	$(ECHO) "# nagios: -epn" >> $@
	$(ECHO) >> $@
	$(ECHO) "my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );" >> $@
	$(ECHO) "my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );" >> $@
	for m in ${EXTRA_MODULES}; do \
		$(SED) -e 's/^1;//g' < $$m | $(AWK) -f ./subst | $(GREP) -v "my %ERROR" >> $@; \
	done
	if [ -d "${MYMODULES_DIR}" ]; then \
		for m in ${MYMODULES_DIR}/CheckMySQLHealthExt*.pm; do \
			if [ -f $$m ]; then \
				$(ECHO) found $$m; \
				$(SED) -e 's/^1;//g' < $$m | $(AWK) -f ./subst | $(GREP) -v "my %ERROR" >> $@; \
			fi \
		done \
	fi
	$(CAT) check_mysql_health.pl | $(GREP) -v "^use Nagios" | $(GREP) -v "^my %ERROR" | $(AWK) -f ./subst >> $@
	chmod +x $@
