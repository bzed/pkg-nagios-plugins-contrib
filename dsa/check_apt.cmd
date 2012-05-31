# check_multi command file implementing a
# check_apt replacement
#
# example nrpe.cfg config:
# command[check_apt]=/usr/lib/nagios/plugins/check_multi -f /etc/check_multi/check_apt.cmd
#
# requirements:
#  - moreutils
#  - the following sudo permissions:
#       nagios  ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/check_libs
#       nagios  ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/check_running_kernel
#  - a cronjob running update-apt-status:
#       @hourly  root [ -x /usr/lib/nagios/cronjobs/update-apt-status ] && /usr/lib/nagios/cronjobs/update-apt-status 2>&1 | logger -t update-apt-status



command[ packages ]		= mispipe "/usr/lib/nagios/plugins/check_statusfile /var/cache/nagios_status/apt"  "sed -n '1p;\$p' | paste -s -d ''"
command[ libs ]			= mispipe "sudo /usr/lib/nagios/plugins/check_libs" "sed 's, ([0-9, ]*),,g'"
command[ running_kernel ]	= sudo /usr/lib/nagios/plugins/check_running_kernel


state   [ CRITICAL ] = COUNT(CRITICAL) > 0
state   [ WARNING ] = COUNT(WARNING) > 0
state   [ UNKNOWN ] = COUNT(UNKNOWN) > 0
