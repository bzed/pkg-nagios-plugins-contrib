# $Id$

AC_PREREQ(2.59)
AC_COPYRIGHT([Copyright (c) 2007-2011 Varnish Software AS])
AC_REVISION([$Id$])
AC_INIT([varnish-nagios], [1.1], [varnish-dev@varnish-cache.org])
AC_CONFIG_SRCDIR(check_varnish.c)
AM_CONFIG_HEADER(config.h)

AC_CANONICAL_SYSTEM
AC_LANG(C)

AM_INIT_AUTOMAKE

# Checks for programs.
AC_GNU_SOURCE
AC_PROG_CC
AC_PROG_CPP
AC_PROG_INSTALL
AC_PROG_LIBTOOL
AC_PROG_MAKE_SET

# Checks for libraries.
PKG_CHECK_MODULES([VARNISHAPI], [varnishapi >= 4.1],
  [AC_DEFINE([HAVE_VARNISHAPI_4_1], [1], [Use VARNISHAPI v4.1])],
  [PKG_CHECK_MODULES([VARNISHAPI], [varnishapi >= 4],
    [AC_DEFINE([HAVE_VARNISHAPI_4], [1], [Use VARNISHAPI v4])],
    [PKG_CHECK_MODULES([VARNISHAPI], [varnishapi >= 3],
      [AC_DEFINE([HAVE_VARNISHAPI_3], [1], [Use VARNISHAPI v3])],
      [AC_MSG_ERROR([Could not find neither varnishapi v4 nor v3.])])
    ]
  )
  ]
)

# Checks for header files.
AC_HEADER_STDC
AC_HEADER_SYS_WAIT
AC_HEADER_TIME

# Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST

# Checks for library functions.
AC_TYPE_SIZE_T
AC_SEARCH_LIBS([pow],[m],[],[AC_MSG_ERROR([unable to find libm])])

# Now that we're done using the compiler to look for functions and
# libraries, set CFLAGS to what we want them to be for our own code

# This corresponds to FreeBSD's WARNS level 6
DEVELOPER_CFLAGS="-Wall -Wstrict-prototypes -Wmissing-prototypes -Wpointer-arith -Wreturn-type -Wcast-qual -Wwrite-strings -Wswitch -Wshadow -Wcast-align -Wunused-parameter -Wchar-subscripts -Winline -Wnested-externs -Wredundant-decls -Wformat"

# Additional flags for GCC 4
EXTRA_DEVELOPER_CFLAGS="-Wextra -Wno-missing-field-initializers -Wno-sign-compare"

AC_ARG_ENABLE(developer-warnings,
	AS_HELP_STRING([--enable-developer-warnings],[enable strict warnings (default is NO)]),
	CFLAGS="${CFLAGS} ${DEVELOPER_CFLAGS}")
AC_ARG_ENABLE(debugging-symbols,
	AS_HELP_STRING([--enable-debugging-symbols],[enable debugging symbols (default is NO)]),
	CFLAGS="${CFLAGS} -O0 -g -fno-inline")
AC_ARG_ENABLE(extra-developer-warnings,
	AS_HELP_STRING([--enable-extra-developer-warnings],[enable even stricter warnings (default is NO)]),
	CFLAGS="${CFLAGS} ${EXTRA_DEVELOPER_CFLAGS}")
AC_ARG_ENABLE(stack-protector,
	AS_HELP_STRING([--enable-stack-protector],[enable stack protector (default is NO)]),
	CFLAGS="${CFLAGS} -fstack-protector-all")
AC_ARG_ENABLE(werror,
	AS_HELP_STRING([--enable-werror],[use -Werror (default is NO)]),
	CFLAGS="${CFLAGS} -Werror")

# Generate output
AC_CONFIG_FILES([
    Makefile
])
AC_OUTPUT
