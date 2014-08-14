Summary:   A Nagios plugin to check HP blade enclosures
Name:      check_hp_bladechassis
Version:   1.0.1
Release:   1%{?dist}
License:   GPL
Packager:  Trond Hasle Amundsen <t.h.amundsen@usit.uio.no>
Group:     Applications/System
BuildRoot: %{_tmppath}/%{name}-%{version}-root
URL:       http://folk.uio.no/trondham/software/%{name}.html
Source0:   http://folk.uio.no/trondham/software/%{name}-%{version}.tar.gz
BuildRequires: perl

Requires: perl >= 5.6.0
Requires: perl(Net::SNMP)
Requires: perl(Getopt::Long)

%description
check_hp_bladechassis is a plugin for the Nagios monitoring
software which checks the hardware health of HP blade enclosures via
SNMP. The plugin is only tested with the c7000 enclosure.

%prep
%setup -q

%build
pod2man -s 8 -r "%{name} %{version}" -c "Nagios plugin" %{name}.pod %{name}.8
gzip %{name}.8

%install
mkdir -p %{buildroot}/%{_libdir}/nagios/plugins
mkdir -p %{buildroot}/%{_mandir}/man8
install -p -m 0755 %{name} %{buildroot}/%{_libdir}/nagios/plugins
install -m 0644 %{name}.8.gz %{buildroot}/%{_mandir}/man8

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%doc README COPYING CHANGES
%{_libdir}/nagios/plugins/%{name}
%attr(0755, root, root) %{_mandir}/man8/%{name}.8.gz


%changelog
* Fri Jan 22 2010 Trond H. Amundsen <t.h.amundsen@usit.uio.no> - 1.0.1-1
- Version 1.0.1
- Added buildrequires perl, fixed requires for perl modules
- New location of script and manpage

* Fri Aug 14 2009 Trond H. Amundsen <t.h.amundsen@usit.uio.no> - 1.0.0-1
- Initial release
