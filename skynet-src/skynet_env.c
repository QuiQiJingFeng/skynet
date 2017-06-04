#include "skynet.h"
#include "skynet_env.h"
//自旋锁
#include "spinlock.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <assert.h>

struct skynet_env {
	struct spinlock lock;		//自旋锁
	lua_State *L;
};

static struct skynet_env *E = NULL;
//从虚拟机中获取全局变量
const char * 
skynet_getenv(const char *key) {
	//对skynet_env 加锁,如果已经有锁，则等待直到锁被解开后才往下执行
	SPIN_LOCK(E)

	lua_State *L = E->L;
	
	lua_getglobal(L, key);
	const char * result = lua_tostring(L, -1);
	lua_pop(L, 1);
	//对skynet_env 解锁
	SPIN_UNLOCK(E)

	return result;
}
//向虚拟机中写入全局变量 
/*
	Lua堆栈
	   栈顶
	----------
  -1|        |4
  -2|        |3
  -3|        |2
  -4|        |1
	----------
	   栈底
*/
void 
skynet_setenv(const char *key, const char *value) {
	SPIN_LOCK(E)
	
	lua_State *L = E->L;
	lua_getglobal(L, key);
	//FYD 由此可知 一个值如果赋值两遍要崩掉的
	assert(lua_isnil(L, -1));
	lua_pop(L,1);
	lua_pushstring(L,value);
	lua_setglobal(L,key);

	SPIN_UNLOCK(E)
}
//初始化skynet_env  创建一个虚拟机
void
skynet_env_init() {
	E = skynet_malloc(sizeof(*E));
	SPIN_INIT(E)
	E->L = luaL_newstate();
}
