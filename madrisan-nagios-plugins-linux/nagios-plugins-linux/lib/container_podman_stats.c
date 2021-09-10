// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * License: GPLv3+
 * Copyright (c) 2020 Davide Madrisan <davide.madrisan@gmail.com>
 *
 * A library for checking for Podman metrics via varlink calls.
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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <varlink.h>

#include "common.h"
#include "container_podman.h"
#include "logging.h"
#include "messages.h"
#include "string-macros.h"
#include "xasprintf.h"

void
podman_stats (podman_varlink_t *pv, stats_type which_stats,
	      bool report_perc, total_t *total, unit_shift shift,
	      const char *image, char **status, char **perfdata)
{
  char *errmsg = NULL, *total_str;
  long ret;
  size_t size;
  unsigned long containers = 0, count, i;
  VarlinkArray *list;

  /* see the enum type 'stats_type' declared in container_podman.h */
  char const * which_stats_str[] = {
     "block input",
     "block output",
     "cpu",
     "memory",
     "network input",
     "network output",
     "pids"
  };
  assert (sizeof (which_stats_str) / sizeof (char *) != last_stats);

  FILE *stream = open_memstream (perfdata, &size);

  if (which_stats == cpu_stats)
    total->lf = 0.0;
  else
    total->llu = 0;

  ret = podman_varlink_list (pv, &list, &errmsg);
  if (ret < 0)
    plugin_error (STATE_UNKNOWN, 0, "varlink_varlink_list: %s", errmsg);

  count = varlink_array_get_n_elements (list);
  dbg ("varlink has detected %lu containers\n", count);

  for (i = 0; i < count; i++)
    {
      bool cnt_running;
      char shortid[PODMAN_SHORTID_LEN];
      const char *cnt_id, *cnt_image, *cnt_status;
      container_stats_t stats;
      VarlinkObject *state;

      varlink_array_get_object (list, i, &state);
      varlink_object_get_string (state, "id", &cnt_id);
      varlink_object_get_string (state, "image", &cnt_image);
      varlink_object_get_bool (state, "containerrunning", &cnt_running);
      varlink_object_get_string (state, "status", &cnt_status);

      podman_shortid (cnt_id, shortid);

      dbg ("podman container %s (%s)\n", cnt_id, shortid);
      dbg (" * container image: %s\n", cnt_image);
      dbg (" * container is running: %s (status: %s)\n",
	   cnt_running ? "yes" : "no", cnt_status);

      /* discard non running containers */
      if (!cnt_running)
	continue;
      /* discard containers non running the selected image if any */
      if (image && STRNEQ (cnt_image, image))
	continue;

      containers++;

      ret = podman_varlink_stats (pv, shortid, &stats, &errmsg);
      if (ret < 0)
	plugin_error (STATE_UNKNOWN, 0, "varlink_varlink_stats: %s", errmsg);

      switch (which_stats)
	{
	default:
	  /* this should never happen */
	  plugin_error (STATE_UNKNOWN, 0, "unknown podman container metric");
	  break;
	case block_in_stats:
	  fprintf (stream, "%s=%ldkB ", stats.name, (stats.block_input / 1000));
	  total->llu += stats.block_input;
	  break;
	case block_out_stats:
	  fprintf (stream, "%s=%ldkB ",
		   stats.name, (stats.block_output / 1000));
	  total->llu += stats.block_output;
	  break;
	case cpu_stats:
	  fprintf (stream, "%s=%.2lf%% ", stats.name, stats.cpu);
	  total->lf += stats.cpu;
	  break;
	case memory_stats:
	  if (report_perc)
	    fprintf
	      (stream, "%s=%.2f%% ", stats.name,
	        ((double)(stats.mem_usage) / (double)(stats.mem_limit)) * 100);
	  else
	    fprintf (stream, "%s=%ldkB;;;0;%ld ", stats.name,
		     (stats.mem_usage / 1000), (stats.mem_limit / 1000));
	  total->llu += stats.mem_usage;
	  break;
	case network_in_stats:
	  fprintf (stream, "%s=%ldB ", stats.name, stats.net_input);
	  total->llu += stats.net_input;
	  break;
	case network_out_stats:
	  fprintf (stream, "%s=%ldB ", stats.name, stats.net_output);
	  total->llu += stats.net_output;
	  break;
	case pids_stats:
	  fprintf (stream, "%s=%ld ", stats.name, stats.pids);
	  total->llu += stats.pids;
	  break;
	}

      free (stats.name);
    }

  fclose (stream);

  if ((which_stats != pids_stats) && (which_stats != cpu_stats))
    switch (shift)
      {
      default:
      case b_shift:
	total_str = xasprintf ("%lluB", total->llu);
	break;
      case k_shift:
	total_str = xasprintf ("%llukB", total->llu / 1000);
	break;
      case m_shift:
	total_str = xasprintf ("%gMB", total->llu / 1000000.0);
	break;
      case g_shift:
	total_str = xasprintf ("%gGB", total->llu / 1000000000.0);
	break;
      }
  else if (which_stats == pids_stats)
    total_str = xasprintf ("%llu", total->llu);
  else
    total_str = xasprintf ("%.2lf%%", total->lf);

  *status =
    xasprintf ("%s of %s used by %lu running container%s", total_str,
	       which_stats_str[which_stats], containers,
	       (containers > 1) ? "s" : "");

  free (total_str);
}
