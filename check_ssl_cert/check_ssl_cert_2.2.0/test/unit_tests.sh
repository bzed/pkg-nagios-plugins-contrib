#!/bin/sh

# $SHUNIT2 should be defined as an environment variable before running the tests
# shellcheck disable=SC2154
if [ -z "${SHUNIT2}" ] ; then
    cat <<EOF
To be able to run the unit test you need a copy of shUnit2
You can download it from https://github.com/kward/shunit2

Once downloaded please set the SHUNIT2 variable with the location
of the 'shunit2' script
EOF
    exit 1
fi

if [ ! -x "${SHUNIT2}" ] ; then
    echo "Error: the specified shUnit2 script (${SHUNIT2}) is not an executable file"
    exit 1
fi

SCRIPT=../check_ssl_cert
if [ ! -r "${SCRIPT}" ] ; then
    echo "Error: the script to test (${SCRIPT}) is not a readable file"
fi

oneTimeSetUp() {
    # constants

    NAGIOS_OK=0
    NAGIOS_WARNING=1
    NAGIOS_CRITICAL=2
    NAGIOS_UNKNOWN=3

    # we trigger a test by Qualy's SSL so that when the last test is run the result will be cached
    echo 'Starting SSL Lab test (to cache the result)'
    curl --silent 'https://www.ssllabs.com/ssltest/analyze.html?d=ethz.ch&latest' > /dev/null

    # check in OpenSSL supports dane checks
    if openssl s_client -help 2>&1 | grep -q -- -dane_tlsa_rrdata || openssl s_client not_a_real_option 2>&1 | grep -q -- -dane_tlsa_rrdata; then
        echo "dane checks supported"
        DANE=1
    fi

}

testHoursUntilNow() {
    # testing with perl
    export DATETYPE='PERL'
    hours_until "$( date )"
    assertEquals "error computing the missing hours until now" 0 "${HOURS_UNTIL}"
}

testHoursUntil5Hours() {
    # testing with perl
    export DATETYPE='PERL'
    hours_until "$( perl -e '$x=localtime(time+(5*3600));print $x' )"
    assertEquals "error computing the missing hours until now" 5 "${HOURS_UNTIL}"
}

testHoursUntil42Hours() {
    # testing with perl
    export DATETYPE='PERL'
    hours_until "$( perl -e '$x=localtime(time+(42*3600));print $x' )"
    assertEquals "error computing the missing hours until now" 42 "${HOURS_UNTIL}"
}

testOpenSSLVersion1() {
    export OPENSSL_VERSION='OpenSSL 1.1.1j  16 Feb 2021'
    export REQUIRED_VERSION='1.2.0a'
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    openssl_version "${REQUIRED_VERSION}"
    RET=$?
    assertEquals "error comparing required version ${REQUIRED_VERSION} to current version ${OPENSSL_VERSION}" 1 "${RET}"
    export OPENSSL_VERSION=
}

testOpenSSLVersion2() {
    export OPENSSL_VERSION='OpenSSL 1.1.1j  16 Feb 2021'
    export REQUIRED_VERSION='1.1.1j'
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    openssl_version "${REQUIRED_VERSION}"
    RET=$?
    assertEquals "error comparing required version ${REQUIRED_VERSION} to current version ${OPENSSL_VERSION}" 0 "${RET}"
    export OPENSSL_VERSION=
}

testOpenSSLVersion3() {
    export OPENSSL_VERSION='OpenSSL 1.1.1j  16 Feb 2021'
    export REQUIRED_VERSION='1.0.0b'
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    openssl_version "${REQUIRED_VERSION}"
    RET=$?
    assertEquals "error comparing required version ${REQUIRED_VERSION} to current version ${OPENSSL_VERSION}" 0 "${RET}"
    export OPENSSL_VERSION=
}

testOpenSSLVersion4() {
    export OPENSSL_VERSION='OpenSSL 1.0.2k-fips 26 Jan 2017'
    export REQUIRED_VERSION='1.0.0b'
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    openssl_version "${REQUIRED_VERSION}"
    RET=$?
    assertEquals "error comparing required version ${REQUIRED_VERSION} to current version ${OPENSSL_VERSION}" 0 "${RET}"
    export OPENSSL_VERSION=
}

testOpenSSLVersion5() {
    export OPENSSL_VERSION='OpenSSL 1.1.1h-freebsd 22 Sep 2020'
    export REQUIRED_VERSION='1.0.0b'
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    openssl_version "${REQUIRED_VERSION}"
    RET=$?
    assertEquals "error comparing required version ${REQUIRED_VERSION} to current version ${OPENSSL_VERSION}" 0 "${RET}"
    export OPENSSL_VERSION=
}

testDependencies() {
    check_required_prog openssl
    # $PROG is defined in the script
    # shellcheck disable=SC2154
    assertNotNull 'openssl not found' "${PROG}"
}

testSCT() {
    OPENSSL=$( command -v openssl ) # needed by openssl_version
    ${OPENSSL} version
    if openssl_version '1.1.0' ; then
	echo "OpenSSL >= 1.1.0: SCTs supported"
        ${SCRIPT} --rootcert-file cabundle.crt -H no-sct.badssl.com
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
    else
	echo "OpenSSL < 1.1.0: SCTs not supported"
        ${SCRIPT} --rootcert-file cabundle.crt -H no-sct.badssl.com
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    fi
}

testUsage() {
    ${SCRIPT} > /dev/null 2>&1
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testMissingArgument() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com --critical > /dev/null 2>&1
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testMissingArgument2() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com --critical --warning 10 > /dev/null 2>&1
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testGroupedVariables() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com -vvv > /dev/null 2>&1
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testGroupedVariablesError() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com -vvxv > /dev/null 2>&1
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testETHZ() {
    ${SCRIPT} --rootcert-file cabundle.crt -H ethz.ch --cn ethz.ch --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testLetsEncrypt() {
    ${SCRIPT} --rootcert-file cabundle.crt -H helloworld.letsencrypt.org --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testGoDaddy() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.godaddy.com --cn www.godaddy.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testETHZCaseInsensitive() {
    ${SCRIPT} --rootcert-file cabundle.crt -H ethz.ch --cn ETHZ.CH --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testETHZWildCard() {
    # * should not match, see https://serverfault.com/questions/310530/should-a-wildcard-ssl-certificate-secure-both-the-root-domain-as-well-as-the-sub
    # we ignore the altnames as sp.ethz.ch is listed
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch --cn sp.ethz.ch --ignore-altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testETHZWildCardCaseInsensitive() {
    # * should not match, see https://serverfault.com/questions/310530/should-a-wildcard-ssl-certificate-secure-both-the-root-domain-as-well-as-the-sub
    # we ignore the altnames as sp.ethz.ch is listed
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch --cn SP.ETHZ.CH --ignore-altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testETHZWildCardSub() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch --cn sub.sp.ethz.ch --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testETHZWildCardSubCaseInsensitive() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch --cn SUB.SP.ETHZ.CH --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testRootIssuer() {
    ${SCRIPT} --rootcert-file cabundle.crt -H google.com --issuer 'GlobalSign' --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testValidity() {
    # Tests bug #8
    ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch -w 1000
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_WARNING}" "${EXIT_CODE}"
}

testValidityWithPerl() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch -w 1000 --force-perl-date
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_WARNING}" "${EXIT_CODE}"
}

testAltNames() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.inf.ethz.ch --cn www.inf.ethz.ch --altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

#Do not require to match Alternative Name if CN already matched
testWildcardAltNames1() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch --altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

#Check for wildcard support in Alternative Names
testWildcardAltNames2() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sherlock.sp.ethz.ch \
        --cn somehost.spapps.ethz.ch \
        --cn otherhost.sPaPPs.ethz.ch \
        --cn spapps.ethz.ch \
         --critical 1 --warning 2 \
        --altnames \

    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testAltNamesCaseInsensitve() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.inf.ethz.ch --cn WWW.INF.ETHZ.CH --altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testMultipleAltNamesFailOne() {
    # Test with wiltiple CN's but last one is wrong
    ${SCRIPT} --rootcert-file cabundle.crt -H inf.ethz.ch -n www.ethz.ch -n wrong.ch --altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testMultipleAltNamesFailTwo() {
    # Test with multiple CN's but first one is wrong
    ${SCRIPT} --rootcert-file cabundle.crt -H inf.ethz.ch -n wrong.ch -n www.ethz.ch --altnames --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testXMPPHost() {
    out=$(${SCRIPT} --rootcert-file cabundle.crt -H prosody.xmpp.is --port 5222 --protocol xmpp --xmpphost xmpp.is  --critical 1 --warning 2)
    EXIT_CODE=$?
    if echo "${out}" | grep -q "s_client' does not support '-xmpphost'" ; then
        assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
    else
        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    fi
}

testTimeOut() {
    ${SCRIPT} --rootcert-file cabundle.crt -H gmail.com --protocol imap --port 993 --timeout  1 --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testIMAP() {
    # minimal critical and warning as they renew pretty late
    ${SCRIPT} --rootcert-file cabundle.crt -H imap.gmx.com --port 143 --timeout 30 --protocol imap --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testIMAPS() {
    ${SCRIPT} --rootcert-file cabundle.crt -H imap.gmail.com --port 993 --timeout 30 --protocol imaps --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testPOP3S() {
    ${SCRIPT} --rootcert-file cabundle.crt -H pop.gmail.com --port 995 --timeout 30 --protocol pop3s --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}


testSMTP() {
    ${SCRIPT} --rootcert-file cabundle.crt -H smtp.gmail.com --protocol smtp --port 25 --timeout 60 --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testSMTPSubmbission() {
    ${SCRIPT} --rootcert-file cabundle.crt -H smtp.gmail.com --protocol smtp --port 587 --timeout 60 --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testSMTPS() {
    ${SCRIPT} --rootcert-file cabundle.crt -H smtp.gmail.com --protocol smtps --port 465 --timeout 60 --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

# Disabled as test.rebex.net is currently not workin. Should find another public FTP server with TLS
#testFTP() {
#    ${SCRIPT} --rootcert-file cabundle.crt -H test.rebex.net --protocol ftp --port 21 --timeout 60
#    EXIT_CODE=$?
#    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
#}
#
#testFTPS() {
#    ${SCRIPT} --rootcert-file cabundle.crt -H test.rebex.net --protocol ftps --port 990 --timeout 60
#    EXIT_CODE=$?
#    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
#}

################################################################################
# From https://badssl.com

testBadSSLExpired() {
    ${SCRIPT} --rootcert-file cabundle.crt -H expired.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLExpiredAndWarnThreshold() {
    ${SCRIPT} --rootcert-file cabundle.crt -H expired.badssl.com --warning 3000
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLWrongHost() {
    ${SCRIPT} --rootcert-file cabundle.crt -H wrong.host.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLSelfSigned() {
    ${SCRIPT} --rootcert-file cabundle.crt -H self-signed.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLUntrustedRoot() {
    ${SCRIPT} --rootcert-file cabundle.crt -H untrusted-root.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLRevoked() {
    ${SCRIPT} --rootcert-file cabundle.crt -H revoked.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLRevokedCRL() {
    ${SCRIPT} --rootcert-file cabundle.crt -H revoked.badssl.com --crl --ignore-ocsp --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testGRCRevoked() {
    ${SCRIPT} --rootcert-file cabundle.crt -H revoked.grc.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLIncompleteChain() {
    ${SCRIPT} --rootcert-file cabundle.crt -H incomplete-chain.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLDH480(){
    ${SCRIPT} --rootcert-file cabundle.crt -H dh480.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLDH512(){
    ${SCRIPT} --rootcert-file cabundle.crt -H dh512.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLRC4MD5(){
    # older versions of OpenSSL validate RC4-MD5
    if ! openssl ciphers RC4-MD5 > /dev/null 2>&1 ; then
        ${SCRIPT} --rootcert-file cabundle.crt -H rc4-md5.badssl.com --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
    else
        echo "OpenSSL too old to test RC4-MD5 ciphers"
    fi
}

testBadSSLRC4(){
    # older versions of OpenSSL validate RC4
    if ! openssl ciphers RC4 > /dev/null 2>&1 ; then
        ${SCRIPT} --rootcert-file cabundle.crt -H rc4.badssl.com --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
    else
        echo "OpenSSL too old to test RC4-MD5 ciphers"
    fi
}

testBadSSL3DES(){
    # older versions of OpenSSL validate RC4
    if ! openssl ciphers 3DES > /dev/null 2>&1 ; then
        ${SCRIPT} --rootcert-file cabundle.crt -H 3des.badssl.com --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
      else
        echo "OpenSSL too old to test 3DES ciphers"
    fi
}

testBadSSLNULL(){
    ${SCRIPT} --rootcert-file cabundle.crt -H null.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLSHA256() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sha256.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLEcc256() {
    ${SCRIPT} --rootcert-file cabundle.crt -H ecc256.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLEcc384() {
    ${SCRIPT} --rootcert-file cabundle.crt -H ecc384.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLRSA8192() {
    ${SCRIPT} --rootcert-file cabundle.crt -H rsa8192.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLLongSubdomainWithDashes() {
    ${SCRIPT} --rootcert-file cabundle.crt -H long-extended-subdomain-name-containing-many-letters-and-dashes.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLLongSubdomain() {
    ${SCRIPT} --rootcert-file cabundle.crt -H longextendedsubdomainnamewithoutdashesinordertotestwordwrapping.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testBadSSLSHA12016() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sha1-2016.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testBadSSLSHA12017() {
    ${SCRIPT} --rootcert-file cabundle.crt -H sha1-2017.badssl.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testMultipleOCSPHosts() {
    ${SCRIPT} --rootcert-file cabundle.crt -H netlock.hu --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testRequireOCSP() {
    ${SCRIPT} --rootcert-file cabundle.crt -H videolan.org --require-ocsp-stapling --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

# tests for -4 and -6
testIPv4() {
    if openssl s_client -help 2>&1 | grep -q -- -4 ; then
        ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com -4 --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    else
        echo "Skipping forcing IPv4: no OpenSSL support"
    fi
}

testIPv6() {
    if openssl s_client -help 2>&1 | grep -q -- -6 ; then

	IPV6=
	if command -v ifconfig > /dev/null && ifconfig -a | grep -q -F inet6 ; then
	    IPV6=1
	elif command -v ip > /dev/null && ip addr | grep -q -F inet6 ; then
	    IPV6=1
	fi

        if [ -n "${IPV6}" ] ; then

	    echo "IPv6 is configured"

            if ping -6 www.google.com > /dev/null 2>&1  ; then

                ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com -6 --critical 1 --warning 2
                EXIT_CODE=$?
                assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"

            else
                echo "IPv6 is configured but not working: skipping test"
            fi

        else
            echo "Skipping forcing IPv6: not IPv6 configured locally"
        fi

    else
        echo "Skipping forcing IPv6: no OpenSSL support"
    fi
}

testFormatShort() {
    OUTPUT=$( ${SCRIPT} --rootcert-file cabundle.crt -H ethz.ch --cn ethz.ch  --critical 1 --warning 2 --format "%SHORTNAME% OK %CN% from '%CA_ISSUER_MATCHED%'" | cut '-d|' -f 1 )
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    assertEquals "wrong output" "SSL_CERT OK ethz.ch from 'QuoVadis Global SSL ICA G2'" "${OUTPUT}"
}

testMoreErrors() {
    OUTPUT=$( ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch --email doesnotexist --critical 1000 --warning 1001 --verbose | wc -l | sed 's/\ //g' )
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    # we should get three lines: the plugin output and three errors
    assertEquals "wrong number of errors" 5 "${OUTPUT}"
}

testMoreErrors2() {
    OUTPUT=$( ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch --email doesnotexist --warning 1000 --warning 1001 --verbose | wc -l | sed 's/\ //g' )
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    # we should get three lines: the plugin output and three errors
    assertEquals "wrong number of errors" 5 "${OUTPUT}"
}

# dane

testDANE211() {
    # dig is needed for DANE
    if command -v dig > /dev/null ; then

        # on github actions the dig command produces no output
        if dig +short TLSA _25._tcp.hummus.csx.cam.ac.uk | grep -q -f 'hummus' ; then

            # check if a connection is possible
            if printf 'QUIT\\n' | openssl s_client -connect hummus.csx.cam.ac.uk:25 -starttls smtp > /dev/null 2>&1 ; then
                ${SCRIPT} --rootcert-file cabundle.crt --dane 211  --port 25 -P smtp -H hummus.csx.cam.ac.uk --critical 1 --warning 2
                EXIT_CODE=$?
                if [ -n "${DANE}" ] ; then
                    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
                else
                    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
                fi
            else
                echo "connection to hummus.csx.cam.ac.uk:25 not possible: skipping test"
            fi
        else
            echo "no TLSA entries in DNS: skipping DANE test"
        fi
    else
        echo "dig not available: skipping DANE test"
    fi
}

# does not work anymore
#testDANE311SMTP() {
#    ${SCRIPT} --rootcert-file cabundle.crt --dane 311 --port 25 -P smtp -H mail.ietf.org
#    EXIT_CODE=$?
#    if [ -n "${DANE}" ] ; then
#        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
#    else
#        assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
#    fi
#}
#
#testDANE311() {
#    ${SCRIPT} --rootcert-file cabundle.crt --dane 311 -H www.ietf.org
#    EXIT_CODE=$?
#    if [ -n "${DANE}" ] ; then
#        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
#    else
#        assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
#    fi
#}

testDANE301ECDSA() {
    if command -v dig > /dev/null ; then
        ${SCRIPT} --rootcert-file cabundle.crt --dane 301 --ecdsa -H mail.aegee.org --critical 1 --warning 2
        EXIT_CODE=$?
        if [ -n "${DANE}" ] ; then
            assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
        else
            assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
        fi
    else
        echo "dig not available: skipping DANE test"
    fi
}

testRequiredProgramFile() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com --file-bin /doesnotexist --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testRequiredProgramPermissions() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.google.com --file-bin /etc/hosts --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_UNKNOWN}" "${EXIT_CODE}"
}

testSieveECDSA() {
    if ! { openssl s_client -starttls sieve 2>&1 | grep -F -q 'Value must be one of:' || openssl s_client -starttls sieve 2>&1 | grep -F -q 'usage:' ; } ; then
        ${SCRIPT} --rootcert-file cabundle.crt -P sieve -p 4190 -H mail.aegee.org --ecdsa --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    else
        echo "Skipping sieve tests (not supported)"
    fi
}

testHTTP2() {
    ${SCRIPT} --rootcert-file cabundle.crt -H rwserve.readwritetools.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testForceHTTP2() {
    if openssl s_client -help 2>&1 | grep -q -F alpn ; then
        ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch --protocol h2 --critical 1 --warning 2
        EXIT_CODE=$?
        assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
    else
        echo "Skupping forced HTTP2 test as -alpn is not supported"
    fi
}

testNotLongerValidThan() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch --not-valid-longer-than 2 --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testDERCert() {
    ${SCRIPT} --rootcert-file cabundle.crt -H localhost -f ./der.cer --ignore-sct --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testPKCS12Cert() {
    export PASS=
    ${SCRIPT} --rootcert-file cabundle.crt -H localhost -f ./client.p12 --ignore-sct --password env:PASS --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testCertificsteWithoutCN() {
    ${SCRIPT} --rootcert-file cabundle.crt -H localhost -n www.uue.org -f ./cert_with_subject_without_cn.crt --force-perl-date --ignore-sig-alg --ignore-sct --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testCertificsteWithEmptySubject() {
    ${SCRIPT} --rootcert-file cabundle.crt -H localhost -n www.uue.org -f ./cert_with_empty_subject.crt --force-perl-date --ignore-sig-alg --ignore-sct --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testResolveSameName() {
    ${SCRIPT} --rootcert-file cabundle.crt -H www.ethz.ch --resolve www.ethz.ch --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testResolveDifferentName() {
    ${SCRIPT} --rootcert-file cabundle.crt -H corti.li --resolve www.google.com --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testResolveCorrectIP() {
    ${SCRIPT} --rootcert-file cabundle.crt -H corti.li --resolve "$( dig +short corti.li )" --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

testResolveWrongIP() {
    ${SCRIPT} --rootcert-file cabundle.crt -H corti.li --resolve "$( dig +short www.google.com )" --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"
}

testCiphersOK() {

    # nmap ssl-enum-ciphers dumps core on CentOS 7 and RHEL 7
    if [ -f /etc/redhat-release ] && grep -q '.*Linux.*release\ 7\.' /etc/redhat-release ; then
        echo 'Skipping tests on CentOS and RedHat 7 since nmap is crashing (core dump)'
    else

        # check if nmap is installed
        if command -v nmap > /dev/null ; then

            # check if ssl-enum-ciphers is present
            if ! nmap --script ssl-enum-ciphers 2>&1 | grep -q -F 'NSE: failed to initialize the script engine' ; then

                ${SCRIPT} --rootcert-file cabundle.crt -H cloudflare.com --check-ciphers C --critical 1 --warning 2
                EXIT_CODE=$?
                assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"

            else
                echo "no ssl-enum-ciphers nmap script found: skipping ciphers test"
            fi

        else
            echo "no nmap found: skipping ciphers test"
        fi

    fi

}

testCiphersError() {

    # nmap ssl-enum-ciphers dumps core on CentOS 7 and RHEL 7
    if [ -f /etc/redhat-release ] && grep -q '.*Linux.*release\ 7\.' /etc/redhat-release ; then
        echo 'Skipping tests on CentOS and RedHat 7 since nmap is crashing (core dump)'
    else

        # check if nmap is installed
        if command -v nmap > /dev/null ; then

            # check if ssl-enum-ciphers is present
            if ! nmap --script ssl-enum-ciphers 2>&1 | grep -q -F 'NSE: failed to initialize the script engine' ; then

                ${SCRIPT} --rootcert-file cabundle.crt -H ethz.ch --check-ciphers A --check-ciphers-warnings --critical 1 --warning 2
                EXIT_CODE=$?
                assertEquals "wrong exit code" "${NAGIOS_CRITICAL}" "${EXIT_CODE}"

            else
                echo "no ssl-enum-ciphers nmap script found: skipping ciphers test"
            fi

        else
            echo "no nmap found: skipping ciphers test"
        fi

    fi

}

# SSL Labs (last one as it usually takes a lot of time

testETHZWithSSLLabs() {
    # we assume www.ethz.ch gets at least a B
    ${SCRIPT} --rootcert-file cabundle.crt -H ethz.ch --cn ethz.ch --check-ssl-labs B --critical 1 --warning 2
    EXIT_CODE=$?
    assertEquals "wrong exit code" "${NAGIOS_OK}" "${EXIT_CODE}"
}

# the script will exit without executing main
export SOURCE_ONLY='test'

# source the script.
# Do not follow
# shellcheck disable=SC1090
. "${SCRIPT}"

unset SOURCE_ONLY

# run shUnit: it will execute all the tests in this file
# (e.g., functions beginning with 'test'
#
# We clone to output to pass it to grep as shunit does always return 0
# We parse the output to check if a test failed
#

# Do not follow
# shellcheck disable=SC1090
. "${SHUNIT2}"
