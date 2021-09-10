// SPDX-License-Identifier: GPL-3.0-or-later
/* cpudesc.h -- a library for checking the CPU features

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

#ifndef _CPUDESC_H
#define _CPUDESC_H

#include "system.h"

#ifdef __cplusplus
extern "C"
{
#endif

  /* Processor characteristics */
  bool get_processor_is_hot_pluggable (unsigned int cpu);
  int get_processor_is_online (unsigned int cpu);

  struct cpu_desc;

  /* Allocates space for a new cpu_desc object.
   * Returns 0 if all went ok. Errors are returned as negative values.  */
  int cpu_desc_new (struct cpu_desc **cpudesc);

  /* Fill the cpu_desc structure pointed with the values found in the 
   * proc filesystem */
  void cpu_desc_read (struct cpu_desc * __restrict cpudesc);

  /* Drop a reference of the cpu_desc library context. If the refcount of
   * reaches zero, the resources of the context will be released.  */
  struct cpu_desc *cpu_desc_unref (struct cpu_desc *cpudesc);

  /* Accessing the values from cpu_desc */
  char *cpu_desc_get_architecture (struct cpu_desc *cpudesc);
  char *cpu_desc_get_vendor (struct cpu_desc *cpudesc);
  char *cpu_desc_get_family (struct cpu_desc *cpudesc);
  char *cpu_desc_get_model (struct cpu_desc *cpudesc);
  char *cpu_desc_get_model_name (struct cpu_desc *cpudesc);
  char *cpu_desc_get_virtualization_flag (struct cpu_desc *cpudesc);
  char *cpu_desc_get_mhz (struct cpu_desc *cpudesc);
  char *cpu_desc_get_flags (struct cpu_desc *cpudesc);

  enum		/* CPU modes */
  {
    MODE_32BIT = (1 << 1),
    MODE_64BIT = (1 << 2)
  };
  int cpu_desc_get_mode (struct cpu_desc *cpudesc);

  int cpu_desc_get_ncpus (struct cpu_desc *cpudesc);
  int cpu_desc_get_ncpuspos (struct cpu_desc *cpudesc);
  int cpu_desc_get_nthreads (struct cpu_desc *cpudesc);

#ifdef __cplusplus
}
#endif

#endif		/* _CPUDESC_H */
