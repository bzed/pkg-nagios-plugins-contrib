// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * License: GPLv3+
 * Copyright (c) 2016 Davide Madrisan <davide.madrisan@gmail.com>
 *
 * Unit test for lib/messages.c
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

#include "messages.h"
#include "testutils.h"

typedef struct test_data
{
  char *state;
  nagstatus value;
  nagstatus expect_value;
} test_data;

static int
test_nagios_state_string (const void *tdata)
{
  const struct test_data *data = tdata;
  int ret = 0;

  TEST_ASSERT_EQUAL_STRING (state_text (data->value), data->state);
  TEST_ASSERT_EQUAL_NUMERIC (data->value, data->expect_value);
  return ret;
}

static int
mymain (void)
{
  int ret = 0;

#define STR(S) #S
#define DO_TEST(TYPE, EXPECT_VALUE)                         \
  do                                                        \
    {                                                       \
      test_data data = {                                    \
	.state = STR(TYPE),                                 \
	.value = STATE_##TYPE,                              \
	.expect_value = EXPECT_VALUE,                       \
      };                                                    \
      if (test_run("check nagios state " STR(TYPE),         \
		   test_nagios_state_string, (&data)) < 0)  \
	ret = -1;                                           \
    }                                                       \
  while (0)

  DO_TEST (OK, 0);
  DO_TEST (WARNING, 1);
  DO_TEST (CRITICAL, 2);
  DO_TEST (UNKNOWN, 3);
  DO_TEST (DEPENDENT, 4);

  return ret == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}

TEST_MAIN (mymain);
