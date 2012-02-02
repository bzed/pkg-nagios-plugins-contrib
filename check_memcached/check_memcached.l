/* 
    This file is the for the Flex code-generator: http://flex.sourceforge.net/
    It also requires libmemcached: http://libmemcached.org/libMemcached.html

    Build it using:
        make LDFLAGS=-lmemcached check_memcached

    This program was initially developed by Lonely Planet for internal use
    and has kindly been made available to the Open Source community for
    redistribution and further development under the terms of the
    GNU General Public License v3: http://www.gnu.org/licenses/gpl.html

    This program is supplied 'as-is', in the hope that it will be useful, but
    neither Lonely Planet nor the authors make any warranties or guarantees
    as to its correct operation, including its intended function.

    Or in other words:
        Test it yourself, and make sure it works for YOU.

    Author: George Hansper       e-mail:  George.Hansper@lonelyplanet.com.au

*/
%{

/* --------------------------- #include ------------------------------ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* For getopt() */
#include <unistd.h>
extern int optind, opterr, optopt;

#include <errno.h>
#include <libmemcached/memcached.h>

#define print_v(args...) if ( verbose ) fprintf(stderr,args );

#define DEBUG 0
#if DEBUG == 1
	#define print_debug(args...) fprintf(stderr,args );
#else
	#define print_debug(args...)
#endif

YY_BUFFER_STATE yy_memcache_buffer;

#define YY_USER_ACTION buffer_position+=yyleng;

/* --------------------------- static/global variables ------------------------------ */

static int  default_port = 11211;
static int  max_n_stats = 30;
static int  min_stats_interval = 30;		/* Compare stats at least 30 minutes old, at least */
static int  verbose=0;
static double min_hit_miss = 2.0;
static uint64_t max_evictions = 10;
static double  timeout=1.0;

static char *hostname;
static int  port;
static char *argv0;

static char *memcached_key = "check_memcached";		/* The key we will store our data under */

/* The expiry time on the stats object, in seconds. Two hours between checks is pretty generous */
static int  memcache_stats_object_expiry_time = 60*60*2;

static char *memory_error_message = "CRITICAL: Could not allocate memory";

static int buffer_position;
static memcached_stat_st stats;
static uint64_t obj_time_last = 0;
static uint64_t obj_time_oldest = 0;
static uint64_t obj_time = 0;
static int      obj_n_prune = 0;
static int      obj_n_stats;
static uint64_t obj_get_hits;
static uint64_t obj_get_misses;
static uint64_t obj_evictions;
static uint64_t obj_cmd_get;
static uint64_t obj_cmd_set;
static uint64_t *save_to;

/* --------------------------- functions() ------------------------------ */
void usage();
int check_memcached();
char * get_new_stats(memcached_st*);
char * update_stats_obj(char *, size_t , char *);

/* ===================================================================================== */
%}

%option yylineno

%s FIND_OFFSET FIND_STATS DUMMY

%%
<DUMMY>.|\n			ECHO;
time=			{ save_to = &obj_time_last; obj_n_stats++; }
get_hits=		{ save_to = &obj_get_hits; }
get_misses=		{ save_to = &obj_get_misses; }
evictions=		{ save_to = &obj_evictions; }
cmd_get=		{ save_to = &obj_cmd_get; }
cmd_set=		{ save_to = &obj_cmd_set; }
<FIND_STATS>[0-9]+	{
				if ( save_to != NULL  ) {
					if ( save_to == &obj_time_last ) {
						/* New time-stamp */
						(*save_to) = (uint64_t) strtoll(yytext, NULL, 10);
						save_to = NULL; 
						if ( obj_time_last <= stats.time - 60*min_stats_interval && 
						     obj_time_last > obj_time ) {
							obj_time = obj_time_last;
							/* Remove any stale data */
							obj_get_hits = 0;
							obj_get_misses = 0;
							obj_evictions = 0;
							obj_cmd_get = 0;
							obj_cmd_set = 0;
						}
						if( obj_time_oldest == 0 || obj_time_last < obj_time_oldest ) {
							obj_time_oldest = obj_time_last;
						}
					} else if( obj_time == obj_time_last ) {
						/* New cadidate data - save it */
						(*save_to) = (uint64_t) strtoll(yytext, NULL, 10);
						save_to = NULL; 
					}
				}
			}
<FIND_OFFSET>[0-9]+	;	/* Don't convert or save integers, just find the offset of the 1st item to keep */
<FIND_OFFSET>\n		{
				if ( obj_n_stats >= obj_n_prune ) {
					return(buffer_position);
				}
			}
<FIND_OFFSET><<EOF>>	{ return(buffer_position); }
"\t"|" "			;
.			{ save_to = NULL; }
\n			{ save_to = NULL; }
%%
/* ==================================================================================================== */

yywrap() {
	return 1;
}

/* ==================================================================================================== */
int main(int argc, char **argv) {
	char opt_c;
	int arg_int;
	char *trail_c;
	int n;
	int i;
	int result;
	int arg_error = 0;
	argv0 = argv[0];
	while ( ( opt_c = getopt(argc, argv, "hvH:p:w:c:t:T:n:E:k:K:") ) != -1 ) {
		switch( opt_c ) {
		case 'H':
			/* Hostname or IP address - support for comma-separated list */
			hostname = malloc(sizeof(char) * (strlen(optarg)+1));
			result = sscanf(optarg, "%[-.0-9a-zA-Z_]%n:%d%n",hostname,&n,&port,&n);
			print_debug("%d+%d # >>> %s <<< === %d ===  %s\n",result,n,hostname, port, optarg);
			switch(result) {
				case 1:
					/* Port not specified - use default_port */
					port = 0;
					break;
				case 2:
					/* OK hostname:port specified */
					break;
				default:
					arg_error = 1;
					break;
			}
			break;
		case 'p':
			arg_int = strtol(optarg,&trail_c,10);
			if ( *trail_c != '\0' ) {
				fprintf(stderr,"option \"-p port\": port must be a number, not \"%s\"\n",optarg);
				arg_error = 1;
			} else {
				default_port = arg_int;
			}
			break;
		case 'n':
			arg_int = strtol(optarg,&trail_c,10);
			if ( *trail_c != '\0' ) {
				fprintf(stderr,"option \"-n max_stats\": max_stats must be a number, not \"%s\"\n",optarg);
				arg_error = 1;
			} else {
				max_n_stats = arg_int;
			}
			break;
		case 'T':
			min_stats_interval = strtol(optarg,NULL,10);
			break;
		case 'v':
			verbose=1;
			break;
		case 'w':
			min_hit_miss = strtod(optarg,NULL);
			break;
		case 'E':
			max_evictions = strtoll(optarg,NULL,10);
			break;
		case 't':
			timeout = strtod(optarg,NULL);
			break;
		case 'c':
			/* Ignored - for now */
			break;
		case 'k':
			if ( optarg != NULL && strlen(optarg) > 1 ) {
				memcached_key = optarg;
			}
			break;
		case 'K':
			memcache_stats_object_expiry_time = strtol(optarg,NULL,10);
			break;
		case 'h':
		default:
			arg_error = 1;
			break;
		}
	}
	if ( port == 0 ) {
		port = default_port;
	}
	if ( arg_error || hostname == NULL ) {
		usage();
		exit(1);
	}

	return (check_memcached());
}

/* ==================================================================================================== */
int check_memcached() {
	memcached_st		*my_memcached;
	memcached_return	error;
	memcached_result_st	*result;
	uint32_t		flags;
	char			*object;
	char			*new_object;
	size_t			object_size;
	char			new_stats;
	int			n;
	char			*new_item;
	double			hit_miss;
	char			*nagios_service_tmp;
	char			*nagios_service_output;	/* error/warning message */
	char			*nagios_perfdata;	/* Performance data */
	size_t			str_bytes = 0;
	int			nagios_result;

	/* ----------------------------------------------------------------------------------------- */
	/* Connect to the memcached server */

	my_memcached = memcached_create(NULL);
	if ( my_memcached == NULL ) {
		puts("CRITICAL: Could not create memcached_st using memcached_create()\n");
		exit(2);
	}

	error = memcached_server_add(my_memcached, hostname, port);
	if ( error ) {
		printf("CRITICAL: %s\n",memcached_strerror(my_memcached, error));
		exit(2);
	}
	memcached_behavior_set(my_memcached, MEMCACHED_BEHAVIOR_CONNECT_TIMEOUT, (uint64_t) (timeout * 1000));
	memcached_behavior_set(my_memcached, MEMCACHED_BEHAVIOR_POLL_TIMEOUT, (uint64_t) (timeout * 1000));
	memcached_behavior_set(my_memcached, MEMCACHED_BEHAVIOR_NO_BLOCK, 0);

	print_debug("default timeout = %lu %lu %lu %lu... %1.1f\n",my_memcached->connect_timeout,
		my_memcached->poll_timeout,
		my_memcached->snd_timeout,
		my_memcached->rcv_timeout,
		timeout);
	/* ----------------------------------------------------------------------------------------- */
	/* Get the stats from this server */
	new_item = get_new_stats(my_memcached);

	/* ----------------------------------------------------------------------------------------- */
	/* Get our data (if it's there) */
	/* memcached_behavior_set(my_memcached, MEMCACHED_BEHAVIOR_BINARY_PROTOCOL, 0); */
	flags = 0;
	object = memcached_get(my_memcached, memcached_key, strlen(memcached_key), &object_size, &flags, &error);
	print_debug("Object = %p, Length = %lu, Error = %d (%s)\n",object,object_size,error,memcached_strerror(my_memcached, error));
	if ( error ) {
		print_v("No stats history object found (key=%s)\n",memcached_key);
	}

	print_debug("uint64_t = %d, long = %d,  long long = %d\n",sizeof(uint64_t), sizeof(long int), sizeof(long long int));

	print_debug("Here it is...%d bytes\n%s\n\n",object_size,object);
	
	obj_n_stats=0;
	BEGIN(FIND_STATS);
	yy_memcache_buffer = yy_scan_bytes ( object, object_size );
	yylex();
	
	print_debug("Found %d items in stats history\n",obj_n_stats);
	print_debug("Best stats:\ntime=%llu cmd_get=%llu cmd_set=%llu get_hits=%llu get_misses=%llu evictions=%llu\n",
		obj_time,obj_cmd_get,obj_cmd_set,obj_get_hits,obj_get_misses,obj_evictions);
	print_debug("New stats\n%s\n",new_item);

	new_object = update_stats_obj(object, object_size, new_item);
	
	/* ----------------------------------------------------------------------------------------- */
	/* Store new data if it's at least 1 minute newer */
	nagios_result=0;
	nagios_service_output = NULL;
	if( new_object != NULL ) {
		error = memcached_set(my_memcached,
				memcached_key,
				strlen(memcached_key),
				new_object,
				strlen(new_object),		/* trailing \0 is not stored with the object(!) */
				(time_t) memcache_stats_object_expiry_time,	/* Expire after (default) 2 hours */
				0
				);
		if ( error ) {
			str_bytes = asprintf(&nagios_service_output,"Could not store updated stats object - %s; ",
				memcached_strerror(my_memcached, error));
			nagios_result|=2;
		}
	}

	if ( nagios_service_output == NULL ) {
		str_bytes = asprintf(&nagios_service_output,"");
	}
	/* ----------------------------------------------------------------------------------------- */
	/* ---- Analyze the stats, return 0,1,2 as required ---------------------------------------- */
	
	if ( obj_time == 0 ) {
		nagios_service_tmp = nagios_service_output;
		str_bytes = asprintf(&nagios_service_output,
				"%sno stats available yet. Come back in %d minutes; ",
				nagios_service_tmp,
				min_stats_interval - (stats.time - obj_time_oldest ) / 60
				);
		free ( nagios_service_tmp );
	} else {
		/* ---- Evictions ---- */
		if ( max_evictions > 0 && ( stats.evictions - obj_evictions) >= max_evictions ) {
			nagios_result|=1;
			nagios_service_tmp = nagios_service_output;
			str_bytes = asprintf(&nagios_service_output,
					"%sToo many evictions: %d; ",
					nagios_service_tmp,
					stats.evictions - obj_evictions
					);
			free ( nagios_service_tmp );
		}
		
		/* ---- Hit/Miss ratio ---- */
		nagios_service_tmp = nagios_service_output;
		if ( ( stats.get_misses - obj_get_misses ) > 0 ) {
			hit_miss = ( stats.get_hits - obj_get_hits ) * 1.0 / ( stats.get_misses - obj_get_misses );
			if ( hit_miss < min_hit_miss ) {
				nagios_result|=1;
				str_bytes = asprintf(&nagios_service_output,
						"%sLow hit/miss rate: %1.1f; ",
						nagios_service_tmp,
						hit_miss
						);
				free ( nagios_service_tmp );
			/*
			} else {
				str_bytes = asprintf(&nagios_service_output,
						"%shit/miss: %1.1f; ",
						nagios_service_tmp,
						hit_miss
						);
			*/
			}
		/*
		} else {
			str_bytes = asprintf(&nagios_service_output,"%shit/miss: %llu/0; ",
						nagios_service_tmp,
						stats.get_hits - obj_get_hits
			);
		*/
		}

		nagios_service_tmp = nagios_service_output;
		str_bytes = asprintf(&nagios_service_output, 
			"%shits=%llu misses=%llu evictions=%llu interval=%lu mins",
			nagios_service_tmp,
			stats.get_hits - obj_get_hits,
			stats.get_misses - obj_get_misses,
			stats.evictions - obj_evictions,
			(uint32_t) (stats.time - obj_time ) / 60
			);
		free ( nagios_service_tmp );
	}
	/* Add the performance data */
	/* Remove trailing newline from new_item */
	n = strlen(new_item);
	if ( n > 1 && *(new_item+n-1) == '\n' ) {
		*(new_item+n-1) = '\0';
	}
	if ( str_bytes == -1 ) {
		puts(memory_error_message);
		exit(2);
	}
	
	/* Delta times may not apply if no suitable object found. Also, if NO object exists yet, there is nothing to calculate */
	if ( obj_time == 0 ) {
		nagios_perfdata = new_item;
	} else {
		str_bytes = asprintf(&nagios_perfdata, 
			"%s delta_time=%lu delta_cmd_get=%llu delta_cmd_set=%llu delta_get_hits=%llu delta_get_misses=%llu delta_evictions=%llu",
			new_item,
			(uint32_t) ( stats.time - obj_time ),
			stats.cmd_get - obj_cmd_get,
			stats.cmd_set - obj_cmd_set,
			stats.get_hits - obj_get_hits,
			stats.get_misses - obj_get_misses,
			stats.evictions - obj_evictions
			);
	}

	switch(nagios_result) {
		case 0:
			printf("OK: %s|%s\n",nagios_service_output,nagios_perfdata);
			break;
		case 1:
			printf("WARNING: %s|%s\n",nagios_service_output,nagios_perfdata);
			break;
		default:
			printf("CRITICAL: %s|%s\n",nagios_service_output,nagios_perfdata);
			nagios_result = 2;
			break;
	}

	if ( ( stats.get_misses - obj_get_misses ) > 0 ) {
		print_v("\nHit/Miss = %llu / %llu = %1.1f\n",
			stats.get_hits - obj_get_hits,
			stats.get_misses - obj_get_misses,
			hit_miss);
	} else {
		print_v("\nNo misses - very good\n");
	}

	print_v("\nHistory object '%s':\n%s\nNew stats:\n%s (%sstored)\n",memcached_key,object,new_item,
		new_object== NULL? "not ":"");

	memcached_free(my_memcached);

	return(nagios_result);
}

/* ==================================================================================================== */
char *get_new_stats(memcached_st  *my_memcached) {
	memcached_return	error;
	int			str_bytes;
	char			* new_item_format;
	char			* new_item;
	memcached_stat_st	*stats_array;

	/* error = memcached_stat_servername(&stats, NULL, hostname, port); - cannot set timeout, but gives better error responses :-( */
	stats_array = memcached_stat(my_memcached, NULL, &error);

	if ( error ) {
		printf("CRITICAL: Could not connect to server %s:%d - %s (%d)\n",hostname, port,
			memcached_strerror(my_memcached, error), error
			);
		exit(2);
	}
	stats = stats_array[0];
	free(stats_array);

	new_item_format = "time=%lu cmd_get=%llu cmd_set=%llu get_hits=%llu get_misses=%llu evictions=%llu\n";

	str_bytes = asprintf(&new_item,new_item_format,
			stats.time,stats.cmd_get,stats.cmd_set,stats.get_hits,stats.get_misses,stats.evictions);

	obj_time_oldest = stats.time;

	if ( str_bytes == -1 ) {
		puts(memory_error_message);
		exit(2);
	}

	return(new_item);
}

/* ==================================================================================================== */
char * update_stats_obj(char *object, size_t object_size, char *new_item) {
	int	obj_offset;
	char	*new_object;
	size_t	new_object_size;
	size_t	graft_offset;
	int	graft_size;
	char	*s;
	if ( stats.time < obj_time_last + 60 ) {
		/* Only store new stats if at least 1 minute has passed since the last stats were stored */
		print_debug("New stats are less than minute newer than last entry - not stored\n");
		return(NULL);
	}
	/* Prune stats from the start of the object */
	obj_n_prune = 1 + obj_n_stats - max_n_stats;
	if ( obj_n_prune > 0 ) {
		buffer_position=0;
		obj_n_stats = 0;
		BEGIN(FIND_OFFSET);
		yy_memcache_buffer = yy_scan_bytes ( object, object_size );
		obj_offset = yylex();
	} else {
		obj_offset = 0;
	}
	/* 
	while( yylex() ) {
	}
	print_debug("Prune %d items / %d chars from start of object\nNew:\n%s\n",obj_n_prune,obj_offset,object+obj_offset);
	*/
	/* Add extra 2 chars for trailing \n\0 */
	new_object_size = object_size - obj_offset + (size_t) ( (strlen(new_item)+ 2) * sizeof(char));
	new_object = malloc(new_object_size * sizeof(char) );
	if (new_object == NULL ) {
		puts(memory_error_message);
		exit(2);
	}
	graft_size = object_size - obj_offset;
	if ( graft_size > 0 ) {
		memcpy(new_object,object+obj_offset,graft_size);
	} else {
		graft_size = 0;
	}
	/* Ensure there is a \0 on the end of the object */
	*(new_object+graft_size)='\0';
	/* Make sure there is a newline between each item in the list */
	s = new_object + graft_size;
	if ( graft_size > 0 ) {
		while ( ( *s == '\0' || *s == '\n' ) && s > new_object ) {
			/* Trailing \0 and trailing \n - rewind a char or more */
			s--;
		}
		/* Add \n\0 to end of buffer */
		strcpy(++s,"\n");
	}
	strcat(s,new_item);
	return(new_object);
	print_debug("New Object is:\n%s\nNew size:  %d\nReal size: %d\n",new_object, new_object_size, (strlen(new_object)+1));
	return(new_object);
}

/* ==================================================================================================== */

void usage() {
	puts("Usage:");
	printf("\t%s -H hostname[:port] [-v] [-p port] [-t time_out] [-w min_hit_miss] [-n max_stats] [-T min_stats_interval] [-E max_evictions] [-k key] [-K key_expiry_time]\n", argv0);
	printf("\t-H  ... Hostname or IP address (required)\n\t        optional \":port\" overrides -p\n");
	printf("\t-p  ... Port number (default: %u)\n",default_port);
	printf("\t-v  ... verbose messages\n");
	printf("\t-n  ... Keep up to this many items in the history object in memcached (default: %u)\n",max_n_stats);
	printf("\t-T  ... Minimum time interval (in minutes) to use to analyse stats. (default: %u)\n",min_stats_interval);
	printf("\t-w  ... Generate warning if quotient of hits/misses falls below this value (default: %1.1f)\n",min_hit_miss);
	printf("\t-E  ... Generate warning if number of evictions exceeds this threshold. 0=disable. (default: %llu)\n",max_evictions);
	printf("\t-t  ... timeout in seconds (default: %1.1f)\n",timeout);
	printf("\t-k  ... key name for history object (default: %s)\n",memcached_key);
	printf("\t-K  ... expiry time in seconds for history object (default: %u)\n",memcache_stats_object_expiry_time);
	printf("\nExample:\n");
	printf("\t%s -H 192.168.1.1 -p 11212 -w 10 -E 5 -t 0.3 -T 10 -n 10\n",argv0);
	printf("\nNote: the history object \"%s\" will not be updated if the new stats are less than a minute old\n",memcached_key);
	printf(  "      compared to the most recent stats in the \"%s\" object\n",memcached_key);
	
}
