#!/bin/sh

if [ "`uname -m`" = "x86_64" ]; then
    def_install_dir=/usr/lib64/nagios/plugins
else
    def_install_dir=/usr/lib/nagios/plugins
fi
def_mandir=/usr/share/man/man8

if [ "$1" = "-q" ]; then
    install_dir=$def_install_dir
    mandir=$def_mandir
else
    echo -n "Plugin dir [$def_install_dir]: "
    read install_dir
    if [ "$install_dir" = "" ]; then
	install_dir=$def_install_dir
    fi
    echo -n "Man page dir [$def_mandir]: "
    read mandir
    if [ "$mandir" = "" ]; then
	mandir=$def_mandir
    fi
fi

if [ -d $install_dir ]; then
    :
else
    echo "ERROR: Plugin directory $install_dir doesn't exist,"
    echo "ERROR: or is not a directory"
    exit 1
fi

if [ -d $mandir ]; then
    :
else
    echo "ERROR: Man page directory $mandir doesn't exist,"
    echo "ERROR: or is not a directory"
    exit 1
fi

# The script and symlinks
cp check_hp_bladechassis $install_dir

# The man page
cp check_hp_bladechassis.8 $mandir

# Done
echo "done."
exit 0
