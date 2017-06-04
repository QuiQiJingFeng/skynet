#include "skynet.h"

#include "skynet_module.h"
#include "spinlock.h"

#include <assert.h>
#include <string.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define MAX_MODULE_TYPE 32

struct modules {
	int count;
	struct spinlock lock;						//自旋锁
	const char * path;							//cservice/?.so
	struct skynet_module m[MAX_MODULE_TYPE];	//模块数组 存储所有的模块 最大32个
};

static struct modules * M = NULL;
//尝试加载一个C模块
static void *
_try_open(struct modules *m, const char * name) {
	const char *l;
	const char * path = m->path;
	size_t path_size = strlen(path);
	size_t name_size = strlen(name);

	int sz = path_size + name_size;
	//search path
	void * dl = NULL;
	char tmp[sz];
	do
	{
		memset(tmp,0,sz);
		while (*path == ';') path++;
		if (*path == '\0') break;   //如果没有分号直接break
		//extern char *strchr(const char *s,char c);查找字符串s中首次出现字符c的位置。
		l = strchr(path, ';');
		if (l == NULL) l = path + strlen(path);
		int len = l - path;
		int i;
		for (i=0;path[i]!='?' && i < len ;i++) {
			tmp[i] = path[i];
		}
		//将?替换成对应的服务名称
		memcpy(tmp+i,name,name_size);
		if (path[i] == '?') {
			/*
				char *strncpy(char *dest, const char *src, int n)，
				把src所指向的字符串中以src地址开始的前n个字节复制到dest所指的数组中，并返回dest。
			*/
			//将剩余的字节复制过去
			strncpy(tmp+i+name_size,path+i+1,len - i - 1);
		} else {
			fprintf(stderr,"Invalid C service path\n");
			exit(1);
		}
		//加载动态库.so
		dl = dlopen(tmp, RTLD_NOW | RTLD_GLOBAL);
		path = l;
	}while(dl == NULL);

	if (dl == NULL) {
		fprintf(stderr, "try open %s failed : %s\n",name,dlerror());
	}

	return dl;
}
//查询模块中心是否存在某个模块,如果存在则返回该模块的地址,否则返回NULL
static struct skynet_module * 
_query(const char * name) {
	int i;
	for (i=0;i<M->count;i++) {
		if (strcmp(M->m[i].name,name)==0) {
			return &M->m[i];
		}
	}
	return NULL;
}

static int
_open_sym(struct skynet_module *mod) {
	size_t name_size = strlen(mod->name);
	char tmp[name_size + 9]; // create/init/release/signal , longest name is release (7)
	memcpy(tmp, mod->name, name_size);
	strcpy(tmp+name_size, "_create");
	/*
		void*dlsym(void*handle,constchar*symbol)
		根据 动态链接库 操作句柄(handle)与符号(symbol)，返回符号对应的地址。使用这个函数不但可以获取函数地址，也可以获取变量地址。
		handle：由dlopen打开动态链接库后返回的指针；
		symbol：要求获取的函数或全局变量的名称。
		返回值：
		void* 指向函数的地址，供调用使用。

	*/
	//从动态库中获取函数的地址  __create是命名约定
	mod->create = dlsym(mod->module, tmp);
	strcpy(tmp+name_size, "_init");
	mod->init = dlsym(mod->module, tmp);
	strcpy(tmp+name_size, "_release");
	mod->release = dlsym(mod->module, tmp);
	strcpy(tmp+name_size, "_signal");
	mod->signal = dlsym(mod->module, tmp);

	return mod->init == NULL;
}
/*
	获取某个模块地址,如果该模块还没创建,则创建
*/
struct skynet_module * 
skynet_module_query(const char * name) {
	struct skynet_module * result = _query(name);
	if (result)
		return result;
	//对模块中心加自旋锁
	SPIN_LOCK(M)

	result = _query(name); // double check
	//如果不存在该模块,同时模块空间还有剩余
	if (result == NULL && M->count < MAX_MODULE_TYPE) {
		int index = M->count;
		//新建模块
		void * dl = _try_open(M,name);
		if (dl) {
			M->m[index].name = name;
			M->m[index].module = dl;
			//初始化模块
			if (_open_sym(&M->m[index]) == 0) {
				//将模块加入模块中心
				M->m[index].name = skynet_strdup(name);
				M->count ++;
				result = &M->m[index];
			}
		}
	}
	//解开自旋锁
	SPIN_UNLOCK(M)

	return result;
}
//向模块中心插入一个模块
void 
skynet_module_insert(struct skynet_module *mod) {
	SPIN_LOCK(M)

	struct skynet_module * m = _query(mod->name);
	//不能插入重复的模块,模块的数量不能超过最大模块数量32
	assert(m == NULL && M->count < MAX_MODULE_TYPE);
	int index = M->count;
	M->m[index] = *mod;
	++M->count;

	SPIN_UNLOCK(M)
}
//调用模块实例的create方法
void * 
skynet_module_instance_create(struct skynet_module *m) {
	if (m->create) {
		return m->create();
	} else {
		return (void *)(intptr_t)(~0);
	}
}
//调用模块实例的init方法
int
skynet_module_instance_init(struct skynet_module *m, void * inst, struct skynet_context *ctx, const char * parm) {
	return m->init(inst, ctx, parm);
}
//调用模块实例的release方法
void 
skynet_module_instance_release(struct skynet_module *m, void *inst) {
	if (m->release) {
		m->release(inst);
	}
}
//调用模块实例的signal方法
void
skynet_module_instance_signal(struct skynet_module *m, void *inst, int signal) {
	if (m->signal) {
		m->signal(inst, signal);
	}
}
//skynet_module初始化  初始化静态moudules变量M  path->cservice/?.so
void 
skynet_module_init(const char *path) {
	struct modules *m = skynet_malloc(sizeof(*m));
	//初始化count = 0
	m->count = 0;
	//初始化模块中心的路径  cservice/?.so
	m->path = skynet_strdup(path);
	//初始化自旋锁
	SPIN_INIT(m)

	M = m;
}
