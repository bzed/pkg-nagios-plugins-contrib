#!/bin/bash

for i in nagios-check-libs nagios-check-libs.conf; do
    tmp=`mktemp`
    if wget -O ${tmp} "http://svn.noreply.org/svn/weaselutils/trunk/${i}"; then
        mv ${tmp} ${i}
    else
        rm -f ${tmp}
    fi
done
