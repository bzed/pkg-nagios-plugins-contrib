#!/bin/bash

# update all files from the dsa nagios git
find checks sbin share etc -type f | while read i; do
    tmp=`mktemp`
    if wget -O "${tmp}" "https://salsa.debian.org/dsa-team/mirror/dsa-nagios/raw/master/dsa-nagios-checks/${i}"; then
        mv "${tmp}" "$i"
    else
        rm -f "${tmp}"
    fi
done

chmod 755 sbin/*
