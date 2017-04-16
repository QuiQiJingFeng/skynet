#ifndef PROTOBUF_C_STRINGPOOL_H
#define PROTOBUF_C_STRINGPOOL_H

/**
 * String pool
 *
 * TODO: Why we need the string pool???????
 * String pool is a one way link list, each string pool struct has a next link
 */

struct _stringpool;

/**
 * Create a new string pool and plus one page memory (256 bytes)
 */
struct _stringpool * _pbcS_new(void);
/**
 * Delete current string pool node and maintain the link list
 */
void _pbcS_delete(struct _stringpool *pool);
/**
 * Copy str to string pool
 *
 * If current pool avaliable page size is smaller then the string size, create new pool and copy the string to this pool
 */
const char * _pbcS_build(struct _stringpool *pool, const char * str , int sz);

#endif
