#!/bin/bash

# update all files from the dsa nagios git
find checks sbin share etc -type f | while read i; do
    tmp=`mktemp`
    if wget -O "${tmp}" "http://anonscm.debian.org/gitweb/?p=mirror/dsa-nagios.git;a=blob_plain;f=dsa-nagios-checks/${i};hb=HEAD"; then
        mv "${tmp}" "$i"
    else
        rm -f "${tmp}"
    fi
done

chmod 755 sbin/*
