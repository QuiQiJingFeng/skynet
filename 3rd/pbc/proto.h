#ifndef PROTOBUFC_PROTO_H
#define PROTOBUFC_PROTO_H

#include "pbc.h"
#include "map.h"
#include "array.h"
#ifndef _MSC_VER
#include <stdbool.h>
#endif
#include <stddef.h>

/**
 * Proto module
 * This module use to store all prototype meta info
 * Register message type, fields and enums.
 */

struct map_ip;
struct map_si;
struct map_sp;
struct _message;
struct _enum;

#define LABEL_OPTIONAL 0
#define LABEL_REQUIRED 1
#define LABEL_REPEATED 2
#define LABEL_PACKED 3

struct _field {
	int id;
	const char *name;
	int type;
	int label;
	pbc_var default_v;
	union {
		const char * n;
		struct _message * m;
		struct _enum * e;
	} type_name;
};

struct _message {
	const char * key;	// type name
	struct map_ip * id;	// id -> _field
	struct map_sp * name;	// string -> _field
	struct pbc_rmessage * def;	// default message
	struct pbc_env * env;
};

struct _enum {
	const char * key;
	struct map_ip * id;		//<! id -> name
	struct map_si * name;	//<! name -> id
	pbc_var default_v;
};

struct pbc_env {
	struct map_sp * files;	// string -> void *
	struct map_sp * enums;	// string -> _enum
	struct map_sp * msgs;	// string -> _message
	const char * lasterror;
};

/**
 * Register a message type to the pbc env
 * @param p pbc env
 * @param name message type name
 * @return generated meta message
 */
struct _message * _pbcP_init_message(struct pbc_env * p, const char *name);

/**
 * Push a field to a message
 *
 * If the message is not exist, it will be create automaticly
 *
 * @param p pbc env
 * @param name message type name
 * @param f field in this message
 * @param queue TODO: keep atoms for the field
 */
void _pbcP_push_message(struct pbc_env * p, const char *name, struct _field *f , pbc_array queue);

/**
 * Push a enum to the env with the message name
 *
 * All enum was kept in the env
 *
 * @param p pbc env
 * @param name message type name
 * @param table contain each enum value and it's name
 * @param sz how many enum in this table
 * @return brand new enum instance
 */
struct _enum * _pbcP_push_enum(struct pbc_env * p, const char *name, struct map_kv *table, int sz );

/**
 * Get default value for a field in a message
 * @param m the message
 * @param name the field name
 * @param defv [out] default value
 * @return the value type
 */
int _pbcP_message_default(struct _message * m, const char * name, pbc_var defv);

/**
 * Get message by it's type name
 * @param p the pbc env
 * @param name the message type name
 * @return return message pointer if not exist, return null
 */
struct _message * _pbcP_get_message(struct pbc_env * p, const char *name);

/**
 * Get a field's type
 * @param field The field
 * @param type [ out ] this field's type name
 * @return this field type in PBC_type macro number.
 */
int _pbcP_type(struct _field * field, const char **type);

#endif
