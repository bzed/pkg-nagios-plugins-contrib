// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * License: GPLv3+
 * Copyright (c) 2017 Davide Madrisan <davide.madrisan@gmail.com>
 *
 * Unit test for check_load.c
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
 *
 */

#include "testutils.h"
#include "thresholds.h"

/* silence the compiler's warning 'function defined but not used' */
static _Noreturn void print_version (void) __attribute__ ((unused));
static _Noreturn void usage (FILE * out) __attribute__ ((unused));
static void validate_input (int i, double w, double c) __attribute__ ((unused));
static void normalize_loadavg (double *loadavg, int numcpus)
  __attribute__ ((unused));

#define NPL_TESTING
#include "../plugins/check_load.c"
#undef NPL_TESTING

typedef struct test_data
{
  double loadavg[3];
  double wload[3];
  double cload[3];
  bool required[3];
  nagstatus expect_status;
} test_data;

static int
test_loadavg_exit_status (const void *tdata)
{
  const struct test_data *data = tdata;
  nagstatus status;
  int ret = 0;

  status = loadavg_status (data->loadavg, data->wload, data->cload, data->required);

  TEST_ASSERT_EQUAL_NUMERIC (status, data->expect_status);
  return ret;
}

static int
mymain (void)
{
  int ret = 0;

#define DO_TEST(L1,L2,L3, W1,W2,W3, C1,C2,C3, R1,R2,R3, EXPECT)  \
  do                                                             \
    {                                                            \
      test_data data = {                                         \
	.loadavg = { L1, L2, L3 },                               \
	.wload = { W1, W2, W3 },                                 \
	.cload = { C1, C2, C3 },                                 \
	.required = { R1, R2, R3 },                              \
	.expect_status = EXPECT                                  \
      };                                                         \
      if (test_run("check load exit status, expected: " #EXPECT, \
		   test_loadavg_exit_status, &data) < 0)         \
	ret = -1;                                                \
    }                                                            \
  while (0)

  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 3.0, 3.0, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ true, true, true,
	   /* expect_status */ STATE_OK);
  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 1.5, 1.5, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ true, true, true,
	   /* expect_status */ STATE_WARNING);
  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 1.5, 1.5, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ true, false, false,
	   /* expect_status */ STATE_OK);
  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 1.5, 1.5, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ false, true, false,
	   /* expect_status */ STATE_WARNING);
  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 1.5, 1.5, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ false, false, true,
	   /* expect_status */ STATE_OK);
  DO_TEST (/* loadavg */ 2.8, 1.9, 1.3,
	   /* wload */ 3.0, 1.5, 1.5, /* cload */ 4.0, 4.0, 4.0,
	   /* required */ false, true, true,
	   /* expect_status */ STATE_WARNING);
  DO_TEST (/* loadavg */ 2.8, 1.9, 5.5,
	   /* wload */ 1.0, 2.0, 2.0, /* cload */ 3.0, 3.0, 4.0,
	   /* required */ true, true, true,
	   /* expect_status */ STATE_CRITICAL);
  DO_TEST (/* loadavg */ 2.8, 1.9, 5.5,
	   /* wload */ 1.0, 2.0, 2.0, /* cload */ 3.0, 3.0, 4.0,
	   /* required */ true, false, false,
	   /* expect_status */ STATE_WARNING);
  DO_TEST (/* loadavg */ 2.8, 1.9, 5.5,
	   /* wload */ 1.0, 2.0, 3.0, /* cload */ 3.0, 3.0, 6.0,
	   /* required */ false, true, false,
	   /* expect_status */ STATE_OK);
  DO_TEST (/* loadavg */ 2.8, 1.9, 5.5,
	   /* wload */ 1.0, 2.0, 3.0, /* cload */ 3.0, 3.0, 6.0,
	   /* required */ false, false, true,
	   /* expect_status */ STATE_WARNING);

  return ret == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}

TEST_MAIN (mymain)
