/* Experimental host harness: caller owns Server and frees it once. All calls for
 * one live Server must be serialized on one thread, without reentrancy. Buffers
 * must be valid for their declared size during the call and may not alias Server.
 * Never call with a stale handle or after free; C cannot validate pointer lifetime. */
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
typedef struct Server Server;
Server *experiment_server_new(const uint8_t *, size_t, const uint8_t *, size_t, const uint8_t *, size_t, const uint8_t *, size_t);
void experiment_server_free(Server *);
ssize_t experiment_server_input(Server *, const uint8_t *, size_t);
ssize_t experiment_server_output(Server *, uint8_t *, size_t);
int experiment_server_admit(Server *);
ssize_t experiment_server_write(Server *, const uint8_t *, size_t);
ssize_t experiment_server_read(Server *, uint8_t *, size_t);
int experiment_server_close(Server *);
size_t experiment_server_free_count(void);
size_t experiment_server_attempt_count(void);
size_t experiment_server_created_count(void);
int experiment_server_eof(Server *);
