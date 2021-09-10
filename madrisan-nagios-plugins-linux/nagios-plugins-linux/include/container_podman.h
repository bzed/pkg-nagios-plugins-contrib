// SPDX-License-Identifier: GPL-3.0-or-later
/* container_podman.h -- a library for checking Podman containes via varlink

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#ifndef _CONTAINER_PODMAN_H
#define _CONTAINER_PODMAN_H

#include <varlink.h>

#include "units.h"

#ifdef __cplusplus
extern "C"
{
#endif

  enum
  {
    PODMAN_SHORTID_LEN = 13
  };

  typedef struct container_stats
  {
    int64_t block_input;
    int64_t block_output;
    double cpu;
    int64_t mem_limit;
    int64_t mem_usage;
    int64_t net_input;
    int64_t net_output;
    int64_t pids;
    char *name;
  } container_stats_t;

  typedef union total
  {
     unsigned long long llu;
     double lf;
  } total_t;

  typedef enum
  {
    unknown = -1,
    /* these enum variables must be non negative */
    block_in_stats = 0,
    block_out_stats,
    cpu_stats,
    memory_stats,
    network_in_stats,
    network_out_stats,
    pids_stats,
    last_stats = pids_stats
  } stats_type;

#ifndef NPL_TESTING

  typedef struct podman_varlink
  {
    int epoll_fd;
    int signal_fd;
    VarlinkConnection *connection;
    VarlinkObject *parameters;
  } podman_varlink_t;

  long podman_varlink_callback (VarlinkConnection * connection,
				const char *error, VarlinkObject * parameters,
				uint64_t flags, void *userdata);
  long podman_varlink_check_event (podman_varlink_t * pv);
  long podman_varlink_list (podman_varlink_t *pv, VarlinkArray **list,
			    char **err);
  long podman_varlink_stats (podman_varlink_t *pv, const char *shortid,
			     container_stats_t *stats, char **err);
#else

  struct podman_varlink;

#endif

  /* Allocates space for a new varlink object.
   * Returns 0 if all went ok. Errors are returned as negative values.  */
  int podman_varlink_new (podman_varlink_t **pv, char *varlinkaddr);

  /* Drop a reference of the varlink library context. If the refcount of
   * reaches zero, the resources of the context will be released.  */
  podman_varlink_t *podman_varlink_unref (podman_varlink_t *pv);

  int podman_running_containers (podman_varlink_t *pv, unsigned int *count,
				 const char *image, char **perfdata);

  /* Report the containers statistics.  */
  void podman_stats (podman_varlink_t *pv, stats_type which_stats,
		     bool report_perc, total_t *total, unit_shift shift,
		     const char *image_name, char **status, char **perfdata);

  /* Return a string valid for Nagios performance data output.  */
  char* podman_image_name_normalize (const char *image);

  /* Return the short ID in the 'shortid' buffer. This buffer must have a size
   * PODMAN_SHORTID_LEN.  */
  void podman_shortid (const char *id, char *shortid);

#ifdef __cplusplus
}
#endif

#endif				/* _CONTAINER_PODMAN_H */
