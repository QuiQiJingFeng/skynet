#ifndef PROTOBUF_C_H
#define PROTOBUF_C_H

#include <stdio.h>
#include <stdint.h>

#define PBC_ARRAY_CAP 64

#define PBC_NOEXIST -1
#define PBC_INT 1
#define PBC_REAL 2
#define PBC_BOOL 3
#define PBC_ENUM 4
#define PBC_STRING 5
#define PBC_MESSAGE 6
#define PBC_FIXED64 7
#define PBC_FIXED32 8
#define PBC_BYTES 9
#define PBC_INT64 10
#define PBC_UINT 11
#define PBC_UNKNOWN 12
#define PBC_REPEATED 128

/**
 * Use this macro to control PBC write field value if this value is equal with the default value in proto.
 *
 * Set to 0 will make PBC write value when you set the field, even if value is equal with the default.
 * Set to 1 will make PBC check value when write, if the value equal with default nothing write.
 */
#define PBC_NOT_WRITE_DEFAULT_VALUE 0

typedef struct _pbc_array { char _data[PBC_ARRAY_CAP]; } pbc_array[1];

struct pbc_slice {
	void *buffer;
	int len;
};

struct pbc_pattern;		//!< use pattern api to read write message
struct pbc_env;			//!< whole lib env
struct pbc_rmessage;	//!< use to decode message
struct pbc_wmessage;	//!< use to encode message

struct pbc_env * pbc_new(void);
void pbc_delete(struct pbc_env *);

/**
 * Register all proto in the slice to the pbc_env
 *
 * This slice can contain a compiled pb file
 */
int pbc_register(struct pbc_env *, struct pbc_slice * slice);

/**
 * Get a field type in a message
 * @param p pbc env
 * @param typename message type name
 * @param key field name, can be null
 * @param type [ out ] if this field is enum this type will point to enum string name otherwise nothing happen.
 * 				if this field is sub message this is this message's type
 * @return field type in PBC_type macro, return 0 if the message or field not exist
 */
int pbc_type(struct pbc_env *, const char * type_name , const char * key , const char ** type);

/**
 * Get last error message in this env and reset it
 * @return the error message
 */
const char * pbc_error(struct pbc_env *);

union pbc_value {
	struct {
		uint32_t low;
		uint32_t hi;
	} i;
	double f;
	struct pbc_slice s;
	struct {
		int id;
		const char * name;
	} e;
};

/**
 * callback function for each field in the pb
 * @param ud user data, you can pass anything in pbc_decode function
 * @param type this unknown field type number
 * @param typename this unknown field type name
 * @param v this field's value
 * @param key this is the field name
 */
typedef void (*pbc_decoder)(void *ud, int type, const char * typename, union pbc_value *v, int id, const char *key);

/**
 * Function use to decode a pb file, this is only a helper function
 * @apram env pbc env
 * @param typename this proto buffer's type name
 * @param slice contain the buffer to parse
 * @param f callback decode function
 * @param ud user data
 */
int pbc_decode(struct pbc_env * env, const char * type_name , struct pbc_slice * slice, pbc_decoder f, void *ud);

//-------------------------------------------------------------------
// message api
/**
 * Create a read message
 * @param env the pbc env
 * @param typename message type name
 * @param slice contain the message encoded buff
 * @return readable message structure or 0 for an error
 */
struct pbc_rmessage * pbc_rmessage_new(struct pbc_env * env, const char * type_name , struct pbc_slice * slice);
void pbc_rmessage_delete(struct pbc_rmessage *);

/**
 * Get an integer from the message ( number or enum id )
 * @param key field name
 * @param index if this field is repeat, use it as index
 * @param hi if this field is 64bit integer this is high 32 bit value
 * @return value
 */
uint32_t pbc_rmessage_integer(struct pbc_rmessage * , const char *key , int index, uint32_t *hi);

/**
 * Get real number from the message
 * Same as above integer function
 */
double pbc_rmessage_real(struct pbc_rmessage * , const char *key , int index);

/**
 * Get string from the message ( or enum name )
 * @param key field key
 * @param index if this field is repeat, use it as index
 * @param sz length of the returned string
 * @return the string you want
 */
const char * pbc_rmessage_string(struct pbc_rmessage * , const char *key , int index, int *sz);

/**
 * Get sub message from the message
 * Same as above
 */
struct pbc_rmessage * pbc_rmessage_message(struct pbc_rmessage *, const char *key, int index);
/**
 * Get repeated field size
 * @return 0, this field is not set, 1 this field is nonrepeat or only one in it, > 1 how many value in this repeated field.
 */
int pbc_rmessage_size(struct pbc_rmessage *, const char *key);

/**
 * Get next field in this message
 * @param key [ in/out ] current field name null for the first, out with next name, null if there is no next one.
 * @return this field type in PBC_type macro format
 */
int pbc_rmessage_next(struct pbc_rmessage *, const char **key);

/**
 * Create a new write message for encode
 * @param env the pbc env
 * @param typename the message type name
 * @return write message for encode
 */
struct pbc_wmessage * pbc_wmessage_new(struct pbc_env * env, const char *type_name);
void pbc_wmessage_delete(struct pbc_wmessage *);

/**
 * Write integer to this message for negative integer, pass -1 to hi
 * @param key target field name
 * @param low low 32bit number
 * @param hi high 32bit number, for negative pass -1
 */
int pbc_wmessage_integer(struct pbc_wmessage *, const char *key, uint32_t low, uint32_t hi);
int pbc_wmessage_real(struct pbc_wmessage *, const char *key, double v);

/**
 * Write string to this message
 * @param v source string, buff will be copied
 * @param len string length
 */
int pbc_wmessage_string(struct pbc_wmessage *, const char *key, const char * v, int len);

/**
 * Create a new message under this key
 * @param key the field key name
 * @return the sub message under this field
 */
struct pbc_wmessage * pbc_wmessage_message(struct pbc_wmessage *, const char *key);

/**
 * Write whole message into buffer
 * @note the buffer return is alloced inside, and belong the wmessage if you destory the wmessage, this buffer you can't use it anymore.
 * @param slice contain the output buffer and it's length
 * @return it's the slice->buffer
 */
void * pbc_wmessage_buffer(struct pbc_wmessage *, struct pbc_slice * slice);

//-------------------------------------------------------------------
// array api 

int pbc_array_size(pbc_array);
uint32_t pbc_array_integer(pbc_array array, int index, uint32_t *hi);
double pbc_array_real(pbc_array array, int index);
struct pbc_slice * pbc_array_slice(pbc_array array, int index);

void pbc_array_push_integer(pbc_array array, uint32_t low, uint32_t hi);
void pbc_array_push_slice(pbc_array array, struct pbc_slice *);
void pbc_array_push_real(pbc_array array, double v);

//-------------------------------------------------------------------
// pattern api

struct pbc_pattern * pbc_pattern_new(struct pbc_env * , const char * message, const char *format, ...);
void pbc_pattern_delete(struct pbc_pattern *);
// return unused bytes , -1 for error
int pbc_pattern_pack(struct pbc_pattern *, void *input, struct pbc_slice * s);
// <0 for error
int pbc_pattern_unpack(struct pbc_pattern *, struct pbc_slice * s , void * output);

void pbc_pattern_set_default(struct pbc_pattern * , void *data);
void pbc_pattern_close_arrays(struct pbc_pattern *, void *data);

#endif
