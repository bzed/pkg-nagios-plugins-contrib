Summary: A Nagios plugin to check IMAP delivery times
#Name: check_email_delivery
Name: nagios-plugins-check_email_delivery
Version: 0.7.1a
Release: 0.2%{?dist}
License: GPLv2
Group: Applications/System
URL: http://buhacoff.net/software/check_email_delivery/
Source0: http://buhacoff.net/software/check_email_delivery/archive/check_email_delivery-%{version}.tar.gz
#http://exchange.nagios.org/components/com_mtree/attachment.php?link_id=1339&cf_id=30
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

# For handling --help options
Requires: /usr/bin/nroff

%description
The Nagios email delivery plugin uses two other plugins
(smtp send and imap receive), also included, to send a message
to an email account and then check that account for the message
and delete it. The plugin times how long it takes for the
message to be delivered and the warning and critical thresholds
are for this elapsed time.

%prep
#%setup -q
%setup -n check_email_delivery-%{version}

# Avoid filenames with unnecessary punction in them
%{__mv} "./docs/check_smtp_send (Greek's conflicted copy 2011-08-24).pod" \
       ./docs/check_smtp_send-Greeks-conflicted-copy-2011-08-24.pod
%{__mv} "docs/How to connect to IMAP server manually.txt" \
       docs/How-to-connect-to-IMAP-server-manually.txt

%build
# No build required, just drop in place

%install
rm -rf $RPM_BUILD_ROOT
%{__install} -d -m0755 %{buildroot}%{_libdir}/nagios/plugins

# No instlalation procedure, install manually
%{__install} -m0755 -m0755 check_* %{buildroot}%{_libdir}/nagios/plugins
%{__install} -m0755 -m0755 imap_* %{buildroot}%{_libdir}/nagios/plugins


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-, root, root, 0755)
%{_libdir}/nagios/plugins/check_*
%{_libdir}/nagios/plugins/imap_*
%doc CHANGES.txt LICENSE.txt README.txt
%doc docs/*

%changelog
* Sun Feb  5 2012 Nico Kadel-Garcia <nkadel@nkadel-sl6.localdomain> - 0.68-0.1
- Update to 0.7.1a
- Add nroff dependency for --help options

* Thu Nov  3 2011 Nico Kadel-Garcia <nkadel@nkadel-sl6.localdomain> - 0.68-0.1
- Initial build.
