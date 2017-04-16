//
//  pbc-lua.h
//  client
//
//  Created by Louis Huang on 12/4/14.
//
//

#ifndef client_pbc_lua_h
#define client_pbc_lua_h

#ifdef __cplusplus
extern "C" {
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
	
	int luaopen_protobuf_c(lua_State *L);
	
	
#ifdef __cplusplus
}
#endif

#endif
