This file was updated on Sun Oct 21 21:32:12 PDT 2007.

Developer guidelines:
http://nagiosplug.sourceforge.net/developer-guidelines.html

Nagios Plugins:
http://nagiosplugins.org/
Nagios: http://nagios.org and http://nagiosplug.sourceforge.net

Perl library:http://search.cpan.org/dist/Nagios-Plugin/lib/Nagios/Plugin.pm

The email delivery plugin I wrote uses two other plugins
(smtp send and imap receive), also included, to send a message
to an email account and then check that account for the message
and delete it. The plugin times how long it takes for the
message to be delivered and the warning and critical thresholds
are for this elapsed time. 

A few notes:

1. I tried to use the check_smtp plugin for sending mail.  I
can do it on the command line but I can't get the newlines to
happen from the nagios config file (\n doesn't seem to work so smtp
server waits for the '.' but doesn't get it like it does when I
use single quote and newlines from the command line).   So if
you know how to get the check_smtp plugin to send a message from
the nagios config, that one could be used instead of the
check_smtp_send plugin included here (and please let me know)


2. I looked at check_mail.pl by bledi51 and its pretty good,
and also conforms better to nagios perl plugin guidelnes than
mine does.  So I'm going to be revising my plugins to conform
more. 






Finally, usage example from my own nagios config:

define command{
	command_name	check_email_delivery
	command_line	$USER1$/check_email_delivery -H $HOSTADDRESS$ --mailfrom $ARG3$ --mailto $ARG4$ --username $ARG5$ --password $ARG6$ --libexec $USER1$ -w $ARG1$ -c $ARG2$
	}

define service{
        use                             generic-service
        host_name                       mail.your.net
        service_description             EMAIL DELIVERY
        check_command                   check_email_delivery!5!120!sender@your.net!recipient@your.net!recipient@your.net!password
        }


A new usage example equivalent to the old one but using the new --plugins and --token options:

define command{
	command_name	check_email_delivery
	command_line	$USER1$/check_email_delivery -p '$USER1$/check_smtp_send -H $HOSTADDRESS$ --mailfrom $ARG3$ --mailto $ARG4$ -U $ARG5$ -P $ARG6$ --subject "Nagios %TOKEN1%" -w $ARG1$ -c $ARG2$' -p '$USER1$/check_imap_receive -H $HOSTADDRESS$ -U $ARG5$ -P $ARG6$ -s SUBJECT -s "Nagios %TOKEN1%" -w $ARG1$ -c $ARG2$' -w $ARG1$,$ARG1$ -c $ARG2$,$ARG2$
	}

define service{
        use                             generic-service
        host_name                       mail.your.net
        service_description             EMAIL DELIVERY
        check_command                   check_email_delivery!5!120!sender@your.net!recipient@your.net!recipient@your.net!password
        }


References to similar plugins:

pop3(s) email matching plugin by kkvenkit
check_mail.pl by bledi51
check_email_loop.pl by ryanwilliams
check_pop.pl and check_imap.pl by http://www.jhweiss.de/software/nagios.html

