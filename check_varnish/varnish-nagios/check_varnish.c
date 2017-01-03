/*-
 * Copyright (c) 2007-2011 Varnish Software AS
 * All rights reserved.
 *
 * Author: Cecilie Fritzvold <cecilihf@linpro.no>
 * Author: Tollef Fog Heen <tfheen@varnish-software.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 *
 * Nagios plugin for Varnish
 */

#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/time.h>
#include <locale.h>
#include <assert.h>

#if defined(HAVE_VARNISHAPI_4) || defined(HAVE_VARNISHAPI_4_1)
#include <vapi/vsc.h>
#include <vapi/vsm.h>
#elif defined(HAVE_VARNISHAPI_3)
#include "vsc.h"
#include "varnishapi.h"
#endif

static int verbose = 0;

struct range {
	intmax_t	lo;
	intmax_t	hi;
	int		inverted:1;
	int		defined:1;
};

static struct range critical;
static struct range warning;

enum {
	NAGIOS_OK = 0,
	NAGIOS_WARNING = 1,
	NAGIOS_CRITICAL = 2,
	NAGIOS_UNKNOWN = 3,
};

static const char *status_text[] = {
	[NAGIOS_OK] = "OK",
	[NAGIOS_WARNING] = "WARNING",
	[NAGIOS_CRITICAL] = "CRITICAL",
	[NAGIOS_UNKNOWN] = "UNKNOWN",
};

/*
 * Parse a range specification
 */
static int
parse_range(const char *spec, struct range *range)
{
	const char *delim;
	char *end;

	/* @ means invert the range */
	if (*spec == '@') {
		++spec;
		range->inverted = 1;
	} else {
		range->inverted = 0;
	}

	/* empty spec... */
	if (*spec == '\0')
		return (-1);

	if ((delim = strchr(spec, ':')) != NULL) {
		/*
		 * The Nagios plugin documentation says nothing about how
		 * to interpret ":N", so we disallow it.  Allowed forms
		 * are "~:N", "~:", "M:" and "M:N".
		 */
		if (delim - spec == 1 && *spec == '~') {
			range->lo = INTMAX_MIN;
		} else {
			range->lo = strtoimax(spec, &end, 10);
			if (end != delim)
				return (-1);
		}
		if (*(delim + 1) != '\0') {
			range->hi = strtoimax(delim + 1, &end, 10);
			if (*end != '\0')
				return (-1);
		} else {
			range->hi = INTMAX_MAX;
		}
	} else {
		/*
		 * Allowed forms are N
		 */
		range->lo = 0;
		range->hi = strtol(spec, &end, 10);
		if (*end != '\0')
			return (-1);
	}

	/*
	 * Sanity
	 */
	if (range->lo > range->hi)
		return (-1);

	range->defined = 1;
	return (0);
}

/*
 * Check if a given value is within a given range.
 */
static int
inside_range(intmax_t value, const struct range *range)
{

	if (range->inverted)
		return (value < range->lo || value > range->hi);
	return (value >= range->lo && value <= range->hi);
}

/*
 * Check if the thresholds against the value and return the appropriate
 * status code.
 */
static int
check_thresholds(intmax_t value)
{

	if (!warning.defined && !critical.defined)
		return (NAGIOS_UNKNOWN);
	if (critical.defined && !inside_range(value, &critical))
		return (NAGIOS_CRITICAL);
	if (warning.defined && !inside_range(value, &warning))
		return (NAGIOS_WARNING);
	return (NAGIOS_OK);
}

struct stat_priv {
	char *param;
	const char *info;
	intmax_t value;
	int found;
	intmax_t cache_hit;
	intmax_t cache_miss;
};

static int
check_stats_cb(void *priv, const struct VSC_point * const pt)
{
	struct stat_priv *p;
	char tmp[1024];

	if (pt == NULL)
		return(0);

#if defined(HAVE_VARNISHAPI_4_1) || defined(HAVE_VARNISHAPI_4)
	assert(sizeof(tmp) > (strlen(pt->section->fantom->type) + 1 +
			      strlen(pt->section->fantom->ident) + 1 +
			      strlen(pt->desc->name) + 1));
	snprintf(tmp, sizeof(tmp), "%s%s%s%s%s",
		(pt->section->fantom->type[0] == 0 ? "" : pt->section->fantom->type),
		(pt->section->fantom->type[0] == 0 ? "" : "."),
		(pt->section->fantom->ident[0] == 0 ? "" : pt->section->fantom->ident),
		(pt->section->fantom->ident[0] == 0 ? "" : "."),
		 pt->desc->name);
	p = priv;
#endif
#if defined(HAVE_VARNISHAPI_4_1)
	assert(!strcmp(pt->desc->ctype, "uint64_t"));
#elif defined(HAVE_VARNISHAPI_4)
	assert(!strcmp(pt->desc->fmt, "uint64_t"));
#elif defined(HAVE_VARNISHAPI_3)
	assert(sizeof(tmp) > (strlen(pt->class) + 1 +
			      strlen(pt->ident) + 1 +
			      strlen(pt->name) + 1));
	snprintf(tmp, sizeof(tmp), "%s%s%s%s%s",
		(pt->class[0] == 0 ? "" : pt->class),
		(pt->class[0] == 0 ? "" : "."),
		(pt->ident[0] == 0 ? "" : pt->ident),
		(pt->ident[0] == 0 ? "" : "."),
		 pt->name);
	p = priv;
	assert(!strcmp(pt->fmt, "uint64_t"));
#endif
	if (strcmp(tmp, p->param) == 0) {
		p->found = 1;
#if defined(HAVE_VARNISHAPI_4) || defined(HAVE_VARNISHAPI_4_1)
		p->info = pt->desc->sdesc;
#elif defined(HAVE_VARNISHAPI_3)
		p->info = pt->desc;
#endif
		p->value = *(const volatile uint64_t*)pt->ptr;
	} else if (strcmp(p->param, "ratio") == 0) {
		if (strcmp(tmp, "cache_hit") == 0 || strcmp(tmp, "MAIN.cache_hit") == 0) {
			p->found = 1;
			p->cache_hit = *(const volatile uint64_t*)pt->ptr;
		} else if (strcmp(tmp, "cache_miss") == 0 || strcmp(tmp, "MAIN.cache_miss") == 0) {
			p->cache_miss = *(const volatile uint64_t*)pt->ptr;
		}
	}
	return (0);
}

/*
 * Check the statistics for the requested parameter.
 */
static void
check_stats(struct VSM_data *vd, char *param)
{
	int status;
	struct stat_priv priv;

	priv.found = 0;
	priv.param = param;

#if defined(HAVE_VARNISHAPI_4) || defined(HAVE_VARNISHAPI_4_1)
	(void)VSC_Iter(vd, NULL, check_stats_cb, &priv);
#elif defined(HAVE_VARNISHAPI_3)
	(void)VSC_Iter(vd, check_stats_cb, &priv);
#endif
	if (strcmp(param, "ratio") == 0) {
		intmax_t total = priv.cache_hit + priv.cache_miss;
		priv.value = total ? (100 * priv.cache_hit / total) : 0;
		priv.info = "Cache hit ratio";
	}
	if (priv.found != 1) {
		printf("Unknown parameter '%s'\n", param);
		exit(1);
	}

	status = check_thresholds(priv.value);
	printf("VARNISH %s: %s (%'jd)|%s=%jd\n", status_text[status],
	       priv.info, priv.value, param, priv.value);
	exit(status);
}

/*-------------------------------------------------------------------------------*/

static void
help(void)
{

	fprintf(stderr, "usage: "
	    "check_varnish [-lv] [-n varnish_name] [-p param_name [-c N] [-w N]]\n"
	    "\n"
	    "-v              Increase verbosity.\n"
	    "-n varnish_name Specify the Varnish instance name\n"
	    "-p param_name   Specify the parameter to check (see below).\n"
	    "                The default is 'ratio'.\n"
	    "-c [@][lo:]hi   Set critical threshold\n"
	    "-w [@][lo:]hi   Set warning threshold\n"
	    "\n"
	    "All items reported by varnishstat(1) are available - use the\n"
	    "identifier listed in the left column by 'varnishstat -l'.\n"
	    "\n"
	    "Examples for Varnish 3.x:\n"
	    "\n"
	    "uptime          How long the cache has been running (in seconds)\n"
	    "ratio           The cache hit ratio expressed as a percentage of hits to\n"
	    "                hits + misses.  Default thresholds are 95 and 90.\n"
	    "usage           Cache file usage as a percentage of the total cache space.\n"
	    "\n"
	    "Examples for Varnish 4.x:\n"
	    "\n"
	    "ratio           The cache hit ratio expressed as a percentage of hits to\n"
	    "                hits + misses.  Default thresholds are 95 and 90.\n"
	    "MAIN.uptime     How long the cache has been running (in seconds).\n"
	    "MAIN.n_purges   Number of purge operations executed.\n"
	);
	exit(0);
}

static void
usage(void)
{

	fprintf(stderr, "usage: "
	    "check_varnish [-lv] [-n varnish_name] [-p param_name [-c N] [-w N]]\n");
	exit(3);
}


int
main(int argc, char **argv)
{
	struct VSM_data *vd;
	char *param = NULL;
	int opt;

	setlocale(LC_ALL, "");

	vd = VSM_New();
#if defined(HAVE_VARNISHAPI_3)
	VSC_Setup(vd);
#endif

	while ((opt = getopt(argc, argv, VSC_ARGS "c:hn:p:vw:")) != -1) {
		switch (opt) {
		case 'c':
			if (parse_range(optarg, &critical) != 0)
				usage();
			break;
		case 'h':
			help();
			break;
		case 'n':
			VSC_Arg(vd, opt, optarg);
			break;
		case 'p':
			param = strdup(optarg);
			break;
		case 'v':
			++verbose;
			break;
		case 'w':
			if (parse_range(optarg, &warning) != 0)
				usage();
			break;
		default:
			if (VSC_Arg(vd, opt, optarg) > 0)
				break;
			usage();
		}
	}

#if defined(HAVE_VARNISHAPI_4) || defined(HAVE_VARNISHAPI_4_1)
	if (VSM_Open(vd))
		exit(1);
#elif defined(HAVE_VARNISHAPI_3)
	if (VSC_Open(vd, 1))
		exit(1);
#endif

	/* Default: if no param specified, check hit ratio.  If no warning
	 * and critical values are specified either, set these to default.
	 */
	if (param == NULL) {
		param = strdup("ratio");
		if (!warning.defined)
			parse_range("95:", &warning);
		if (!critical.defined)
			parse_range("90:", &critical);
	}

	if (!param)
		usage();

	check_stats(vd, param);

	exit(0);
}
