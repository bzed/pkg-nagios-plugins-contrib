package Monitoring::GLPlugin::SNMP::MibsAndOids::MIB2MIB;

$Monitoring::GLPlugin::SNMP::MibsAndOids::origin->{'MIB-2-MIB'} = {
  url => "",
  name => "MIB-2-MIB",
};

$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{'MIB-2-MIB'} = {
  sysDescr => '1.3.6.1.2.1.1.1',
  sysObjectID => '1.3.6.1.2.1.1.2',
  sysUpTime => '1.3.6.1.2.1.1.3',
  sysName => '1.3.6.1.2.1.1.5',
  sysORTable => '1.3.6.1.2.1.1.9',
  sysOREntry => '1.3.6.1.2.1.1.9.1',
  sysORIndex => '1.3.6.1.2.1.1.9.1.1',
  sysORID => '1.3.6.1.2.1.1.9.1.2',
  sysORDescr => '1.3.6.1.2.1.1.9.1.3',
  sysORUpTime => '1.3.6.1.2.1.1.9.1.4',
};

$Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{'MIB-2-MIB'} = {
  'DateAndTime' => sub {
    my $value = shift;
    use Time::Local;
    my ($month, $day, $hour, $minute, $second, $dseconds, $dirutc, $hoursutc, $minutesutc,
        $wday, $yday, $isdst, $year) =
        (0, 0, 0, 0, 0, 0, "+", 0, 0, 0, 0, 0, 0);
#      DISPLAY-HINT "2d-1d-1d,1d:1d:1d.1d,1a1d:1d"
#      STATUS       current
#      DESCRIPTION
#              "A date-time specification.
#  
#              field  octets  contents                  range
#              -----  ------  --------                  -----
#                1      1-2   year*                     0..65536
#                2       3    month                     1..12
#                3       4    day                       1..31
#                4       5    hour                      0..23
#                5       6    minutes                   0..59
#                6       7    seconds                   0..60
#                             (use 60 for leap-second)
#                7       8    deci-seconds              0..9
#                8       9    direction from UTC        '+' / '-'
#                9      10    hours from UTC*           0..13
#               10      11    minutes from UTC          0..59
#  
#              * Notes:
#              - the value of year is in network-byte order
#              - daylight saving time in New Zealand is +13
#  
#              For example, Tuesday May 26, 1992 at 1:30:15 PM EDT would be
#              displayed as:
#  
#                               1992-5-26,13:30:15.0,-4:0
#  
#              Note that if only local time is known, then timezone
#              information (fields 8-10) is not present."
#      SYNTAX       OCTET STRING (SIZE (8 | 11))

    if ($value && $value !~ /^[ \w,\:\-\+\.]+$/) {
      $value = unpack("H*", $value);
    }
    if ($value && (
        $value =~ /^0x((\w{2} ){8,})/ ||
        $value =~ /^0x((\w{2} ){7,}(\w{2}){1,})/ ||
        $value =~ /^((\w{2}){8,})/ ||
        $value =~ /^((\w{2} ){8,})/ ||
        $value =~ /^((\w{2} ){7,}(\w{2}){1,})/ ||
        $value =~ /^(([0-9a-fA-F][0-9a-fA-F]){6,})$/
    )) {
      $value = $1;
      $value =~ s/ //g;
      $year = hex substr($value, 0, 4);
      $value = substr($value, 4);
      if (length($value) > 12) {
        ($month, $day, $hour, $minute, $second, $dseconds,
            $dirutc, $hoursutc, $minutesutc) = unpack "C*", pack "H*", $value;
        $minutesutc ||= 0;
        $dirutc = ($dirutc == 43) ? "+" : ($dirutc == 45) ? "-" : "+";
        if ($value eq "000000000000000000") {
          $day = 1;
          $month = 1;
          $year = 1970;
        }
      } else {
        ($month, $day, $hour, $minute, $second, $dseconds) = unpack "C*", pack "H*", $value;
        $second ||= 0;
        $dseconds ||= 0;
        my @t = localtime(time);
        my $gmt_offset_in_hours = (timegm(@t) - timelocal(@t)) / 3600;
        ($dirutc, $hoursutc, $minutesutc) = ("+", $gmt_offset_in_hours, 0);
      }
    } elsif ($value && $value =~ /(\d+)-(\d+)-(\d+),(\d+):(\d+):(\d+)\.(\d+),([\+\-]*)(\d+):(\d+)/) {
      ($year, $month, $day, $hour, $minute, $second, $dseconds,
          $dirutc, $hoursutc, $minutesutc) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
    } elsif ($value && $value =~ /(\d+)-(\d+)-(\d+),(\d+):(\d+):(\d+)/) {
      ($year, $month, $day, $hour, $minute, $second, $dseconds) =
          ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
    } else {
      ($second, $minute, $hour, $day, $month, $year, $wday, $yday, $isdst) =
          gmtime(time);
      $year -= 1900;
      $month += 1;
    }
    my $epoch = timegm($second, $minute, $hour, $day, $month-1, $year-1900);
    # 1992-5-26,13:30:15.0,-4:0 = Tuesday May 26, 1992 at 1:30:15 PM EDT
    # Eastern Daylight Time (EDT) is 4 hours behind Coordinated Universal Time (UTC)
    # 13:30:15 EDT = 17:30:15 UTC
    # wir haben gesetzt timegm(13:30:15), d.h. man muss von epoch noch 4 stunden abziehen
    #
    if ($hoursutc || $minutesutc) {
      if ($dirutc && $dirutc eq "+") {
        $epoch -= ($hoursutc * 3600 + $minutesutc);
      } elsif ($dirutc && $dirutc eq "-") {
        $epoch += ($hoursutc * 3600 + $minutesutc);
      }
    }
    return $epoch;
  },
};

1;

__END__
STRING: 2013-12-17,14:3:11.9
STRING: 2015-7-9,12:28:44.0,+1:0
STRING: 2016-12-2,18:56:24.0,+0:0
STRING: 2014-5-21,15:57:56.4,-0:0
STRING: 2017-9-25,7:13:15.0,-4:0
STRING: 2015-8-7,14:51:50.7
STRING: 2017-4-12,13:26:21
Hex-STRING: 07 DF 01 08 0F 02 09 00 2D 01 00
Hex-STRING: 07 E0 02 05 14 16 2D 00 2B 01 00
STRING:
