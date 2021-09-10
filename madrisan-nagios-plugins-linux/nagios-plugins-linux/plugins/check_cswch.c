// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * License: GPLv3+
 * Copyright (c) 2014,2015 Davide Madrisan <davide.madrisan@gmail.com>
 *
 * A Nagios plugin that monitors the total number of context switches
 * per second across all CPUs.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <getopt.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "common.h"
#include "cpustats.h"
#include "messages.h"
#include "progname.h"
#include "progversion.h"
#include "thresholds.h"
#include "xstrton.h"

static const char *program_copyright =
  "Copyright (C) 2014,2015 Davide Madrisan <" PACKAGE_BUGREPORT ">\n";

static struct option const longopts[] = {
  {(char *) "critical", required_argument, NULL, 'c'},
  {(char *) "warning", required_argument, NULL, 'w'},
  {(char *) "verbose", no_argument, NULL, 'v'},
  {(char *) "help", no_argument, NULL, GETOPT_HELP_CHAR},
  {(char *) "version", no_argument, NULL, GETOPT_VERSION_CHAR},
  {NULL, 0, NULL, 0}
};

static _Noreturn void
usage (FILE * out)
{
  fprintf (out, "%s (" PACKAGE_NAME ") v%s\n", program_name, program_version);
  fputs ("This plugin monitors the total number of context switches "
	 "across all CPUs.\n", out);
  fputs (program_copyright, out);
  fputs (USAGE_HEADER, out);
  fprintf (out, "  %s [-v] [-w COUNTER] -c [COUNTER] [delay [count]]\n",
	   program_name);
  fputs (USAGE_OPTIONS, out);
  fputs ("  -w, --warning COUNTER   warning threshold\n", out);
  fputs ("  -c, --critical COUNTER   critical threshold\n", out);
  fputs ("  -v, --verbose   show details for command-line debugging "
	 "(Nagios may truncate output)\n", out);
  fputs (USAGE_HELP, out);
  fputs (USAGE_VERSION, out);
  fprintf (out, "  delay is the delay between updates in seconds "
	   "(default: %dsec)\n", DELAY_DEFAULT);
  fprintf (out, "  count is the number of updates "
	   "(default: %d)\n", COUNT_DEFAULT);
  fputs (USAGE_EXAMPLES, out);
  fprintf (out, "  %s 1 2\n", program_name);

  exit (out == stderr ? STATE_UNKNOWN : STATE_OK);
}

static _Noreturn void
print_version (void)
{
  printf ("%s (" PACKAGE_NAME ") v%s\n", program_name, program_version);
  fputs (program_copyright, stdout);
  fputs (GPLv3_DISCLAIMER, stdout);

  exit (STATE_OK);
}

static unsigned long long
get_ctxtdelta (unsigned int count, unsigned int delay, bool verbose)
{
  int tog = 0;
  unsigned int i;
  unsigned long long nctxt[2],
                     dnctxt = nctxt[0] = cpu_stats_get_cswch ();

  if (verbose)
    printf ("ctxt = %llu\n", dnctxt);

  for (i = 1; i < count; i++)
    {
      sleep (delay);

      tog = !tog;
      nctxt[tog] = cpu_stats_get_cswch ();
      dnctxt = (nctxt[tog] - nctxt[!tog]) / delay;

      if (verbose)
	printf ("ctxt = %llu --> %llu/s\n", nctxt[tog], dnctxt);
    }

   return dnctxt;
}

#ifndef NPL_TESTING
int
main (int argc, char **argv)
{
  int c;
  bool verbose = false;
  char *critical = NULL, *warning = NULL;
  nagstatus status = STATE_OK;
  thresholds *my_threshold = NULL;

  unsigned long count, delay;
  unsigned long long dnctxt;

  set_program_name (argv[0]);

  while ((c = getopt_long (argc, argv,
			   "c:w:v" GETOPT_HELP_VERSION_STRING,
			   longopts, NULL)) != -1)
    {
      switch (c)
	{
	default:
	  usage (stderr);
	case 'c':
	  critical = optarg;
	  break;
	case 'w':
	  warning = optarg;
	  break;
	case 'v':
	  verbose = true;
	  break;

	case_GETOPT_HELP_CHAR
	case_GETOPT_VERSION_CHAR

	}
    }

  delay = DELAY_DEFAULT, count = COUNT_DEFAULT;
  if (optind < argc)
    {
      delay = strtol_or_err (argv[optind++], "failed to parse argument");

      if (delay < 1)
	plugin_error (STATE_UNKNOWN, 0, "delay must be positive integer");
      else if (DELAY_MAX < delay)
	plugin_error (STATE_UNKNOWN, 0,
		      "too large delay value (greater than %d)", DELAY_MAX);
    }

  if (optind < argc)
    {
      count = strtol_or_err (argv[optind++], "failed to parse argument");
      if (COUNT_MAX < count)
	plugin_error (STATE_UNKNOWN, 0,
		      "too large count value (greater than %d)", COUNT_MAX);
    }

  status = set_thresholds (&my_threshold, warning, critical);
  if (status == NP_RANGE_UNPARSEABLE)
    usage (stderr);

  dnctxt = get_ctxtdelta (count, delay, verbose);

  status = get_status (dnctxt, my_threshold);
  free (my_threshold);

  char *time_unit = (count > 1) ? "/s" : "";
  printf ("%s %s - number of context switches%s %llu | cswch%s=%llu\n",
	  program_name_short, state_text (status),
	  time_unit, dnctxt, time_unit, dnctxt);

  return status;
}
#endif			/* NPL_TESTING */
