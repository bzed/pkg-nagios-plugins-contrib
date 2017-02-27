# check_debsecan
Monitoring/Nagios plugin for Debian - Checks the Debian CVE database against all installed packages on your system

Usage: check_debsecan [OPTIONS]

Arguments:
   -f                 warning  value for fixed packages | default = 20
   -F                 critical value for fixed packages | default = 30
   -o                 warning  value for obsolete packages | default = 1
   -O                 critical value for obsolete packages | default = 1
   -l                 warning  value for "low urgency" fixes | default = 10
   -L                 critical value for "low urgency" fixes | default = 20
   -m                 warning  value for "medium urgency" fixes | default = 5
   -M                 critical value for "medium urgency" fixes | default = 10
   -u                 warning  value for urgent "high urgency" fixes | default = 1
   -U                 critical value for urgent "high urgency" fixes | default = 1
   -s                 set the suite parameter manually
   -P "[proxy-url]"   set the proxy manually

Options:
   -d                 produces debugging output
   -r                 disables the cve/packages report
   -h                 print this help

Result:
OK: (F:7;O:0;H:0;M:3;L:1) - 7 security fixes ready to install found!
CVE-2016-8864 libdns-export100 (fixed, remotely exploitable, medium urgency)
CVE-2017-3135 libdns-export100 (fixed)
CVE-2017-5848 gstreamer1.0-plugins-bad (fixed, remotely exploitable, low urgency)
TEMP-0000000-1E5903 libgraphicsmagick-q16-3 (fixed)
CVE-2016-7444 libgnutls-deb0-28 (fixed, remotely exploitable, medium urgency)
CVE-2017-5334 libgnutls-deb0-28 (fixed)
CVE-2017-5027 chromium (fixed, remotely exploitable, medium urgency)
| 'fixed'=7;20;30;0;30 'obsolete'=0;1;1;0;1 'high-urgency'=0;1;1;0;1 'medium-urgency'=3;5;10;0;10 'low-urgency'=1;10;20;0;20


The default thresholds of the check are relatively high, so if you want to check for all CVE's just set -f 1 -F 1 so every CVE popping up will force the check to CRITICAL.


