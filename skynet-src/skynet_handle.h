#ifndef SKYNET_CONTEXT_HANDLE_H
#define SKYNET_CONTEXT_HANDLE_H

#include <stdint.h>
//预留高8位地址为远端ID
// reserve high 8 bits for remote id
#define HANDLE_MASK 0xffffff
#define HANDLE_REMOTE_SHIFT 24

struct skynet_context;
//申请一个没用到的handle
uint32_t skynet_handle_register(struct skynet_context *);
//将指定handle对应的名字空间,skynet_context的引用计数-1
int skynet_handle_retire(uint32_t handle);
//根据handle 返回对应的skynet_context ,如果不存在则返回NULL
struct skynet_context * skynet_handle_grab(uint32_t handle);
//对所有的skynet_context的引用计数-1
void skynet_handle_retireall();
//查找名字空间中是否存在该name 如果找到了返回handle值,如果找不到返回0
uint32_t skynet_handle_findname(const char * name);
//将handle和name进行绑定
const char * skynet_handle_namehandle(uint32_t handle, const char *name);
//初始化 handle_storage
void skynet_handle_init(int harbor);

#endif
