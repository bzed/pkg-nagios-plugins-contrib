%define version          2.2.0
%define release          0
%define sourcename       check_ssl_cert
%define packagename      nagios-plugins-check_ssl_cert
%define nagiospluginsdir %{_libdir}/nagios/plugins

# No binaries in this package
%define debug_package %{nil}

Summary:   A Nagios plugin to check X.509 certificates
Name:      %{packagename}
Version:   %{version}
Obsoletes: check_ssl_cert
Release:   %{release}%{?dist}
License:   GPLv3+
Packager:  Matteo Corti <matteo@corti.li>
Group:     Applications/System
BuildRoot: %{_tmppath}/%{packagename}-%{version}-%{release}-root-%(%{__id_u} -n)
URL:       https://github.com/matteocorti/check_ssl_cert
Source:    https://github.com/matteocorti/check_ssl_cert/releases/download/v%{version}/check_ssl_cert-%{version}.tar.gz

Requires:  nagios-plugins expect perl(Date::Parse)

%description
A shell script (that can be used as a Nagios plugin) to check an SSL/TLS connection

%prep
%setup -q -n %{sourcename}-%{version}

%build

%install
make DESTDIR=${RPM_BUILD_ROOT}%{nagiospluginsdir} MANDIR=${RPM_BUILD_ROOT}%{_mandir} install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc AUTHORS ChangeLog NEWS README.md COPYING VERSION COPYRIGHT
%attr(0755, root, root) %{nagiospluginsdir}/check_ssl_cert
%{_mandir}/man1/%{sourcename}.1*

%changelog
* Fri May   7 2021 Matteo Corti <matteo@corti.li> - 2.2.0-0
- Updated to 2.2.0

* Thu May   6 2021 Matteo Corti <matteo@corti.li> - 2.1.4-0
- Updated to 2.1.4

* Wed May   5 2021 Matteo Corti <matteo@corti.li> - 2.1.3-0
- Updated to 2.1.3

* Fri Apr  30 2021 Matteo Corti <matteo@corti.li> - 2.1.2-0
- Updated to 2.1.2

* Thu Apr  29 2021 Matteo Corti <matteo@corti.li> - 2.1.1-0
- Updated to 2.1.1

* Wed Apr  28 2021 Matteo Corti <matteo@corti.li> - 2.1.0-0
- Updated to 2.1.0

* Wed Apr   7 2021 Matteo Corti <matteo@corti.li> - 2.0.1-0
- Updated to 2.0.1

* Mon Apr   1 2021 Matteo Corti <matteo@corti.li> - 2.0.0-0
- Updated to 2.0.0

* Mon Mar  29 2021 Matteo Corti <matteo@corti.li> - 1.147.0-0
- Updated to 1.147.0

* Thu Mar  25 2021 Matteo Corti <matteo@corti.li> - 1.146.0-0
- Updated to 1.146.0

* Mon Mar  15 2021 Matteo Corti <matteo@corti.li> - 1.145.0-0
- Updated to 1.145.0

* Sun Mar  14 2021 Matteo Corti <matteo@corti.li> - 1.144.0-0
- Updated to 1.144.0

* Fri Mar  12 2021 Matteo Corti <matteo@corti.li> - 1.143.0-0
- Updated to 1.143.0

* Wed Mar  10 2021 Matteo Corti <matteo@corti.li> - 1.142.0-0
- Updated to 1.142.0

* Tue Mar   9 2021 Matteo Corti <matteo@corti.li> - 1.141.0-0
- Updated to 1.141.0

* Thu Feb  25 2021 Matteo Corti <matteo@corti.li> - 1.140.0-0
- Updated to 1.140.0

* Wed Feb  24 2021 Matteo Corti <matteo@corti.li> - 1.139.0-0
- Updated to 1.139.0

* Wed Feb  24 2021 Matteo Corti <matteo@corti.li> - 1.138.0-0
- Updated to 1.138.0

* Thu Feb  18 2021 Matteo Corti <matteo@corti.li> - 1.137.0-0
- Updated to 1.137.0

* Tue Feb  16 2021 Matteo Corti <matteo@corti.li> - 1.136.0-0
- Updated to 1.136.0

* Thu Jan  28 2021 Matteo Corti <matteo@corti.li> - 1.135.0-0
- Updated to 1.135.0

* Wed Jan  27 2021 Matteo Corti <matteo@corti.li> - 1.134.0-0
- Updated to 1.134.0

* Tue Jan  26 2021 Matteo Corti <matteo@corti.li> - 1.133.0-0
- Updated to 1.133.0

* Mon Jan  18 2021 Matteo Corti <matteo@corti.li> - 1.132.0-0
- Updated to 1.132.0

* Fri Jan  15 2021 Matteo Corti <matteo@corti.li> - 1.131.0-0
- Updated to 1.131.0

* Thu Jan  14 2021 Matteo Corti <matteo@corti.li> - 1.130.0-0
- Updated to 1.130.0

* Thu Dec  24 2020 Matteo Corti <matteo@corti.li> - 1.129.0-0
- Updated to 1.129.0

* Tue Dec  22 2020 Matteo Corti <matteo@corti.li> - 1.128.0-0
- Updated to 1.128.0

* Mon Dec  21 2020 Matteo Corti <matteo@corti.li> - 1.127.0-0
- Updated to 1.127.0

* Wed Dec  16 2020 Matteo Corti <matteo@corti.li> - 1.126.0-0
- Updated to 1.126.0

* Fri Dec  11 2020 Matteo Corti <matteo@corti.li> - 1.125.0-0
- Updated to 1.125.0

* Tue Dec   1 2020 Matteo Corti <matteo@corti.li> - 1.124.0-0
- Updated to 1.124.0

* Mon Nov  30 2020 Matteo Corti <matteo@corti.li> - 1.123.0-0
- Updated to 1.123.0

* Fri Aug   7 2020 Matteo Corti <matteo@corti.li> - 1.122.0-0
- Updated to 1.122.0

* Fri Jul  24 2020 Matteo Corti <matteo@corti.li> - 1.121.0-0
- Updated to 1.121.0

* Thu Jul   2 2020 Matteo Corti <matteo@corti.li> - 1.120.0-0
- Updated to 1.120.0

* Wed Jul   1 2020 Matteo Corti <matteo@corti.li> - 1.119.0-0
- Updated to 1.119.0

* Fri Jun  12 2020 Matteo Corti <matteo@corti.li> - 1.118.0-0
- Updated to 1.118.0

* Sat Jun   6 2020 Matteo Corti <matteo@corti.li> - 1.117.0-0
- Updated to 1.117.0

* Thu Jun   4 2020 Matteo Corti <matteo@corti.li> - 1.115.0-0
- Updated to 1.115.0

* Wed May  27 2020 Matteo Corti <matteo@corti.li> - 1.114.0-0
- Updated to 1.114.0

* Tue May  19 2020 Matteo Corti <matteo@corti.li> - 1.113.0-0
- Updated to 1.113.0

* Tue Apr   7 2020 Matteo Corti <matteo@corti.li> - 1.112.0-0
- Updated to 1.112.0

* Mon Mar   9 2020 Matteo Corti <matteo@corti.li> - 1.111.0-0
- Updated to 1.111.0

* Mon Feb  17 2020 Matteo Corti <matteo@corti.li> - 1.110.0-0
- Updated to 1.110.0

* Tue Jan  7 2020 Matteo Corti <matteo@corti.li> - 1.109.0-0
- Updated to 1.109.0

* Mon Dec 23 2019 Matteo Corti <matteo@corti.li> - 1.108.0-0
- Updated to 1.108.0

* Fri Dec 20 2019 Matteo Corti <matteo@corti.li> - 1.107.0-0
- Updated to 1.107.0

* Thu Nov 21 2019 Matteo Corti <matteo@corti.li> - 1.106.0-0
- Updated to 1.106.0

* Mon Nov  4 2019 Matteo Corti <matteo@corti.li> - 1.105.0-0
- Updated to 1.105.0

* Mon Nov  4 2019 Matteo Corti <matteo@corti.li> - 1.104.0-0
- Updated to 1.104.0

* Thu Oct 31 2019 Matteo Corti <matteo@corti.li> - 1.103.0-0
- Updated to 1.103.0

* Fri Oct 25 2019 Matteo Corti <matteo@corti.li> - 1.102.0-0
- Updated to 1.102.0

* Tue Oct 22 2019 Matteo Corti <matteo@corti.li> - 1.101.0-0
- Updated to 1.101.0

* Fri Oct 18 2019 Matteo Corti <matteo@corti.li> - 1.100.0-0
- Updated to 1.100.0

* Wed Oct 16 2019 Matteo Corti <matteo@corti.li> - 1.99.0-0
- Updated to 1.99.0
w
* Thu Oct 10 2019 Matteo Corti <matteo@corti.li> - 1.98.0-0
- Updated to 1.98.0

* Wed Oct  9 2019 Matteo Corti <matteo@corti.li> - 1.97.0-0
- Updated to 1.97.0

* Wed Sep 25 2019 Matteo Corti <matteo@corti.li> - 1.96.0-0
- Updated to 1.96.0

* Tue Sep 24 2019 Matteo Corti <matteo@corti.li> - 1.95.0-0
- Updated to 1.95.0

* Tue Sep 24 2019 Matteo Corti <matteo@corti.li> - 1.94.0-0
- Updated to 1.94.0

* Tue Sep 24 2019 Matteo Corti <matteo@corti.li> - 1.93.0-0
- Updated to 1.93.0

* Tue Sep 24 2019 Matteo Corti <matteo@corti.li> - 1.92.0-0
- Updated to 1.92.0

* Tue Sep 24 2019 Matteo Corti <matteo@corti.li> - 1.91.0-0
- Updated to 1.91.0

* Thu Sep 19 2019 Matteo Corti <matteo@corti.li> - 1.90.0-0
- Updated to 1.90.0

* Thu Aug 22 2019 Matteo Corti <matteo@corti.li> - 1.89.0-0
- Updated to 1.89.0

* Fri Aug  9 2019 Matteo Corti <matteo@corti.li> - 1.88.0-0
- Updated to 1.88.0

* Thu Aug  8 2019 Matteo Corti <matteo@corti.li> - 1.87.0-0
- Updated to 1.87.0

* Sun Jul 21 2019 Matteo Corti <matteo@corti.li> - 1.86.0-0
- Updated to 1.86.0

* Sun Jun  2 2019 Matteo Corti <matteo@corti.li> - 1.85.0-0
- Updated to 1.85.0

* Thu Mar 28 2019 Matteo Corti <matteo@corti.li> - 1.84.0-0
- Updated to 1.84.0

* Fri Mar  1 2019 Matteo Corti <matteo@corti.li> - 1.83.0-0
- Updated to 1.83.0

* Fri Feb  8 2019 Matteo Corti <matteo@corti.li> - 1.82.0-0
- Updated to 1.82.0

* Sat Feb  2 2019 Matteo Corti <matteo@corti.li> - 1.81.0-0
- Updated to 1.81.0

* Wed Jan 16 2019 Matteo Corti <matteo@corti.li> - 1.80.1-0
- Updated to 1.80.1

* Mon Dec 24 2018 Matteo Corti <matteo@corti.li> - 1.80.0-0
- Updated to 1.80.0

* Tue Dec 11 2018 Matteo Corti <matteo@corti.li> - 1.79.0-0
- Updated to 1.79.0

* Wed Nov  7 2018 Matteo Corti <matteo@corti.li> - 1.78.0-0
- Updated to 1.78.0

* Mon Nov  5 2018 Matteo Corti <matteo@corti.li> - 1.77.0-0
- Updated to 1.77.0

* Fri Oct 19 2018 Matteo Corti <matteo@corti.li> - 1.76.0-0
- Updated to 1.76.0

* Thu Oct 18 2018 Matteo Corti <matteo@corti.li> - 1.75.0-0
- Updated to 1.75.0

* Mon Oct 15 2018 Matteo Corti <matteo@corti.li> - 1.74.0-0
- Updated to 1.74.0

* Mon Sep 10 2018 Matteo Corti <matteo@corti.li> - 1.73.0-0
- Updated to 1.73.0

* Mon Jul 30 2018 Matteo Corti <matteo@corti.li> - 1.72.0-0
- Updated to 1.72.0

* Mon Jul 30 2018 Matteo Corti <matteo@corti.li> - 1.71.0-0
- Updated to 1.71.0

* Sat Jun 28 2018 Matteo Corti <matteo@corti.li> - 1.70.0-0
- Updated to 1.70.0

* Mon Jun 25 2018 Matteo Corti <matteo@corti.li> - 1.69.0-0
- Updated to 1.69.0

* Sun Apr 29 2018 Matteo Corti <matteo@corti.li> - 1.68.0-0
- Updated to 1.68.0

* Tue Apr 17 2018 Matteo Corti <matteo@corti.li> - 1.67.0-0
- Updated to 1.67.0

* Fri Apr  6 2018 Matteo Corti <matteo@corti.li> - 1.66.0-0
- Updated to 1.66.0

* Thu Mar 29 2018 Matteo Corti <matteo@corti.li> - 1.65.0-0
- Updated to 1.65.0

* Wed Mar 28 2018 Matteo Corti <matteo@corti.li> - 1.64.0-0
- Updated to 1.64.0

* Sat Mar 17 2018 Matteo Corti <matteo@corti.li> - 1.63.0-0
- Updated to 1.63.0

* Tue Mar  6 2018 Matteo Corti <matteo@corti.li> - 1.62.0-0
- Updated to 1.62.0

* Fri Jan 19 2018 Matteo Corti <matteo@corti.li> - 1.61.0-0
- Updated to 1.61.0

* Fri Dec 15 2017 Matteo Corti <matteo@corti.li> - 1.60.0-0
- Updated to 1.60.0

* Thu Dec 14 2017 Matteo Corti <matteo@corti.li> - 1.59.0-0
- Updated to 1.59.0

* Wed Nov 29 2017 Matteo Corti <matteo@corti.li> - 1.58.0-0
- Updated to 1.58.0

* Tue Nov 28 2017 Matteo Corti <matteo@corti.li> - 1.57.0-0
- Updated to 1.57.0

* Fri Nov 17 2017 Matteo Corti <matteo@corti.li> - 1.56.0-0
- Updated to 1.56.0

* Thu Nov 16 2017 Matteo Corti <matteo@corti.li> - 1.55.0-0
- Updated to 1.55.0

* Tue Sep 19 2017 Matteo Corti <matteo@corti.li> - 1.54.0-0
- Updated to 1.54.0

* Sun Sep 10 2017 Matteo Corti <matteo@corti.li> - 1.53.0-0
- Updated to 1.53.0

* Sat Sep  9 2017 Matteo Corti <matteo@corti.li> - 1.52.0-0
- Updated to 1.52.0

* Fri Jul 28 2017 Matteo Corti <matteo@corti.li> - 1.51.0-0
- Updated to 1.51.0

* Mon Jul 24 2017 Matteo Corti <matteo@corti.li> - 1.50.0-0
- Updated to 1.50.0

* Mon Jul 17 2017 Matteo Corti <matteo@corti.li> - 1.49.0-0
- Updated to 1.49.0

* Fri Jun 23 2017 Matteo Corti <matteo@corti.li> - 1.48.0-0
- Updated to 1.48.0

* Thu Jun 15 2017 Matteo Corti <matteo@corti.li> - 1.47.0-0
- Updated to 1.47.0

* Mon May 15 2017 Matteo Corti <matteo@corti.li> - 1.46.0-0
- Updated to 1.46.0

* Tue May  2 2017 Matteo Corti <matteo@corti.li> - 1.45.0-0
- Updated to 1.45.0

* Fri Apr 28 2017 Matteo Corti <matteo@corti.li> - 1.44.0-0
- Updated to 1.44.0

* Tue Mar  7 2017 Matteo Corti <matteo@corti.li> - 1.43.0-0
- Updated to 1.43.0

* Thu Feb 16 2017 Matteo Corti <matteo@corti.li> - 1.42.0-0
- Updated to 1.42.0

* Fri Feb 10 2017 Matteo Corti <matteo@corti.li> - 1.41.0-0
- Updated to 1.41.0

* Wed Feb  8 2017 Matteo Corti <matteo@corti.li> - 1.40.0-0
- Updated to 1.40.0

* Thu Feb  2 2017 Matteo Corti <matteo@corti.li> - 1.39.0-0
- Updated to 1.39.0

* Thu Feb  2 2017 Matteo Corti <matteo@corti.li> - 1.38.2-0
- Updated to 1.38.2

* Sun Jan 29 2017 Matteo Corti <matteo@corti.li> - 1.38.1-0
- Updated to 1.38.1

* Sat Jan 28 2017 Matteo Corti <matteo@corti.li> - 1.38.0-0
- Updated to 1.38.0

* Fri Dec 23 2016 Matteo Corti <matteo@corti.li> - 1.37.0-0
- Updated to 1.37.0

* Tue Dec 13 2016 Matteo Corti <matteo@corti.li> - 1.36.2-0
- Updated to 1.36.2

* Tue Dec 06 2016 Matteo Corti <matteo@corti.li> - 1.36.1-0
- Updated to 1.36.1

* Sun Dec 04 2016 Matteo Corti <matteo@corti.li> - 1.36.0-0
- Updated to 1.36.0

* Tue Oct 18 2016 Matteo Corti <matteo@corti.li> - 1.35.0-0
- Updated to 1.35.0

* Mon Sep 19 2016 Matteo Corti <matteo@corti.li> - 1.34.0-0
- Updated to 1.34.0

* Thu Aug  4 2016 Matteo Corti <matteo@corti.li> - 1.33.0-0
- Updated to 1.33.0

* Fri Jul 29 2016 Matteo Corti <matteo@corti.li> - 1.32.0-0
- Updated to 1.32.0

* Tue Jul 12 2016 Matteo Corti <matteo@corti.li> - 1.31.0-0
- Updated to 1.31.0

* Thu Jun 30 2016 Matteo Corti <matteo@corti.li> - 1.30.0-0
- Updated to 1.30.0

* Wed Jun 15 2016 Matteo Corti <matteo@corti.li> - 1.29.0-0
- Updated to 1.29.0

* Wed Jun 01 2016 Matteo Corti <matteo@corti.li> - 1.28.0-0
- Updated to 1.28.0

* Wed Apr 27 2016 Matteo Corti <matteo@corti.li> - 1.27.0-0
- Updated to 1.27.0

* Tue Mar 29 2016 Matteo Corti <matteo@corti.li> - 1.26.0-0
- Updated to 1.26.0

* Mon Mar 21 2016 Matteo Corti <matteo@corti.li> - 1.25.0-0
- Updated to 1.25.0

* Wed Mar  9 2016 Matteo Corti <matteo@corti.li> - 1.24.0-0
- Updated to 1.24.0

* Mon Mar  7 2016 Matteo Corti <matteo@corti.li> - 1.23.0-0
- Updated to 1.23.0

* Thu Mar  3 2016 Matteo Corti <matteo@corti.li> - 1.22.0-0
- Updated to 1.22.0

* Tue Mar  1 2016 Matteo Corti <matteo@corti.li> - 1.21.0-0
- Updated to 1.21.0

* Fri Feb 26 2016 Matteo Corti <matteo@corti.li> - 1.20.0-0
- Updated to 1.20.0

* Thu Feb 25 2016 Matteo Corti <matteo@corti.li> - 1.19.0-0
- Updated to 1.19.0

* Sat Oct 31 2015 Matteo Corti <matteo@corti.li> - 1.18.0-0
- Updated to 1.18.0

* Tue Oct 20 2015 Matteo Corti <matteo@corti.li> - 1.17.2-0
- Updated to 1.17.2

* Tue Apr  7 2015 Matteo Corti <matteo@corti.li> - 1.17.1-0
- Updated to 1.17.1

* Tue Oct 21 2014 Matteo Corti <matteo@corti.li> - 1.17.0-0
- Updated to 1.17.0

* Fri Jun  6 2014 Matteo Corti <matteo.corti@id.ethz.ch> - 1.16.2-0
- updated to 1.16.2

* Thu May 22 2014 Andreas Dijkman <andreas.dijkman@cygnis.nl> - 1.16.1-1
- Added noarch as buildarch
- Added expect and perl(Date::Parse) dependency

* Fri Feb 28 2014 Matteo Corti <matteo.corti@id.ethz.ch> - 1.16.1-0
- Updated to 1.16.1 (rpm make target)

* Mon Dec 23 2013 Matteo Corti <matteo.corti@id.ethz.ch> - 1.16.0-0
- Udated to 1.16.0 (force TLS)

* Mon Jul 29 2013 Matteo Corti <matteo.corti@id.ethz.ch> - 1.15.0-0
- Updated to 1.15.0 (force SSL version)

* Sun May 12 2013 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.6-0
- Updated to 1.16.6 (timeout and XMPP support)

* Sat Mar  2 2013 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.5-0
- Updated to 1.14.5 (TLS and multiple names fix)

* Fri Dec  7 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.4-0
- Updated to 1.14.4 (bug fix release)

* Wed Sep 19 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.3-0
- Updated to 1.14.3

* Fri Jul 13 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.2-0
- Updated to 1.14.2

* Wed Jul 11 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.1-0
- Updated to 1.14.1

* Fri Jul  6 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.14.0-0
- updated to 1.14.0

* Thu Apr  5 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.13.0-0
- updated to 1.13.0

* Wed Apr  4 2012 Matteo Corti <matteo.corti@id.ethz.ch> - 1.12.0-0
- updated to 1.12.0 (bug fix release)

* Sat Oct 22 2011 Matteo Corti <matteo.corti@id.ethz.ch> - 1.11.0-0
- ipdated to 1.10.1 (--altnames option)

* Thu Sep  1 2011 Matteo Corti <matteo.corti@id.ethz.ch> - 1.10.0-0
- applied patch from Sven Nierlein for client certificate authentication

* Thu Mar 10 2011 Matteo Corti <matteo.corti@id.ethz.ch> - 1.9.1-0
- updated to 1.9.1: allows http as protocol and fixes -N with wildcards

* Mon Jan 24 2011 Matteo Corti <matteo.corti@id.ethz.ch> - 1.9.0-0
- updated to 1.9.0: --openssl option

* Thu Dec 16 2010 Dan Wallis - 1.8.1-0
- Fixed bugs with environment bleeding & shell globbing

* Thu Dec  9 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.8.0-0
- added support for TLS servername extension

* Thu Oct 28 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.7.7-0
- Fixed a bug in the signal specification

* Thu Oct 28 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.7.6-0
- better temporary file clean up

* Thu Oct 14 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.7.5-0
- updated to 1.7.5 (fixed the check order)

* Fri Oct  1 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.7.4-0
- added -A command line option

* Wed Sep 15 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.7.3-0
- Fixed a bug in the command line options processing

* Thu Aug 26 2010 Dan Wallis - 1.7.2-0
- updated to 1.7.2 (cat and expect fixes)

* Thu Aug 26 2010 Dan Wallis - 1.7.1-0
- updated to 1.7.1 ("-verify 6" revert)

* Thu Aug 26 2010 Dan Wallis - 1.7.0-0

* Wed Jul 21 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.6.1-0
- updated to 1.6.0 (--temp option)

* Fri Jul  9 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.6.0-0
- updated to version 1.6.0 (long options, --critical and --warning, man page)

* Wed Jul  7 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.5.2-0
- updated to version 1.5.2 (Wolfgang Schricker patch, see ChangeLog)

* Thu Jul  1 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.5.1-0
- updated to version 1.5.1 (Yannick Gravel patch, see ChangeLog)

* Tue Jun  8 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.5.0-0
- updated to version 1.5.0 (-s option to allow self signed certificates)

* Thu Mar 11 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.4.4-0
- updated to 1.4.4 (bug fix release)

* Tue Mar  9 2010 Matteo Corti <matteo.corti@id.ethz.ch> - 1.4.3-0
- updated to 1.4.3 (-n and -N options)

* Wed Dec  2 2009 Matteo Corti <matteo.corti@id.ethz.ch> - 1.4.2-0
- updated to 1.4.2

* Mon Nov 30 2009 Matteo Corti <matteo.corti@id.ethz.ch> - 1.4.1-0
- updated to 1.4.1 (-r option)

* Mon Nov 30 2009 Matteo Corti <matteo.corti@id.ethz.ch> - 1.4.0-0
- Updated to 1.4.0: verify the certificate chain

* Mon Mar 30 2009 Matteo Corti <matteo.corti@id.ethz.ch> - 1.3.0-0
- Tuomas Haarala patch: -P option

* Tue May 13 2008 Matteo Corti <matteo.corti@id.ethz.ch> - 1.2.2-0
- Dan Wallis patch to include the CN in the messages

* Mon Feb 25 2008 Matteo Corti <matteo.corti@id.ethz.ch> - 1.2.1-0
- Dan Wallis patches (error checking, see ChangeLog)

* Mon Feb 25 2008 Matteo Corti <matteo.corti@id.ethz.ch> - 1.2.0-0
- Dan Wallis patches (see the ChangeLog)

* Mon Sep 24 2007 Matteo Corti <matteo.corti@id.ethz.ch> - 1.1.0-0
- first RPM package

