#include "skynet.h"

#include "skynet_handle.h"
#include "skynet_server.h"
#include "rwlock.h"

#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define DEFAULT_SLOT_SIZE 4
#define MAX_SLOT_SIZE 0x40000000

struct handle_name {
	char * name;
	uint32_t handle;
};

struct handle_storage {
	struct rwlock lock;				//读写锁

	uint32_t harbor;				//远端标记 放在handle的高8位
	uint32_t handle_index;
	int slot_size;					//槽大小
	struct skynet_context ** slot;	//槽空间 元素:struct skynet_context *
	
	int name_cap;					//名字空间的容量
	int name_count;					//名字空间已经占用的数量
	struct handle_name *name;		//名字空间  元素:handle_name
};
//声明静态handle_storage
static struct handle_storage *H = NULL;
/*
	申请一个没用到的handle
*/
uint32_t
skynet_handle_register(struct skynet_context *ctx) {
	struct handle_storage *s = H;
	//添加写锁
	rwlock_wlock(&s->lock);
	//for(;;) <==> while(true)
	for (;;) {
		int i;
		for (i=0;i<s->slot_size;i++) {
			uint32_t handle = (i+s->handle_index) & HANDLE_MASK;
			int hash = handle & (s->slot_size-1);
			//找到一个没有用到的hash值将ctx放入
			if (s->slot[hash] == NULL) {
				s->slot[hash] = ctx;
				s->handle_index = handle + 1;

				rwlock_wunlock(&s->lock);
				//补上harbor的地址
				handle |= s->harbor;
				return handle;
			}
		}
		//如果没有找到可用的hash则将进行动态扩容
		assert((s->slot_size*2 - 1) <= HANDLE_MASK);
		struct skynet_context ** new_slot = skynet_malloc(s->slot_size * 2 * sizeof(struct skynet_context *));
		memset(new_slot, 0, s->slot_size * 2 * sizeof(struct skynet_context *));
		for (i=0;i<s->slot_size;i++) {
			int hash = skynet_context_handle(s->slot[i]) & (s->slot_size * 2 - 1);
			assert(new_slot[hash] == NULL);
			new_slot[hash] = s->slot[i];
		}
		skynet_free(s->slot);
		s->slot = new_slot;
		s->slot_size *= 2;
	}
}
/*
	将指定handle对应的名字空间,skynet_context的引用计数-1
*/
int
skynet_handle_retire(uint32_t handle) {
	int ret = 0;
	struct handle_storage *s = H;

	rwlock_wlock(&s->lock);

	uint32_t hash = handle & (s->slot_size-1);
	struct skynet_context * ctx = s->slot[hash];
	//如果该handle有对应的skynet_context
	if (ctx != NULL && skynet_context_handle(ctx) == handle) {
		s->slot[hash] = NULL;
		ret = 1;
		//移除handle对应的name,剩下的name依次前移
		int i;
		int j=0, n=s->name_count;
		for (i=0; i<n; ++i) {
			if (s->name[i].handle == handle) {
				skynet_free(s->name[i].name);
				continue;
			} else if (i!=j) {
				s->name[j] = s->name[i];
			}
			++j;
		}
		s->name_count = j;
	} else {
		ctx = NULL;
	}

	rwlock_wunlock(&s->lock);
	//如果ctx存在，则引用计数-1
	if (ctx) {
		// release ctx may call skynet_handle_* , so wunlock first.
		skynet_context_release(ctx);
	}

	return ret;
}
//对所有的skynet_context的引用计数-1
void 
skynet_handle_retireall() {
	struct handle_storage *s = H;
	for (;;) {
		int n=0;
		int i;
		for (i=0;i<s->slot_size;i++) {
			rwlock_rlock(&s->lock);
			struct skynet_context * ctx = s->slot[i];
			uint32_t handle = 0;
			if (ctx)
				handle = skynet_context_handle(ctx);
			rwlock_runlock(&s->lock);
			if (handle != 0) {
				if (skynet_handle_retire(handle)) {
					++n;
				}
			}
		}
		if (n==0)
			return;
	}
}
//根据handle 返回对应的skynet_context ,如果不存在则返回NULL
struct skynet_context * 
skynet_handle_grab(uint32_t handle) {
	struct handle_storage *s = H;
	struct skynet_context * result = NULL;
	//添加读锁
	rwlock_rlock(&s->lock);
	//通过hash取出skynet_contex
	uint32_t hash = handle & (s->slot_size-1);
	struct skynet_context * ctx = s->slot[hash];
	if (ctx && skynet_context_handle(ctx) == handle) {
		result = ctx;
		//将skynet_context的引用计数+1
		skynet_context_grab(result);
	}
	//解开读锁
	rwlock_runlock(&s->lock);

	return result;
}
//查找名字空间中是否存在该name
uint32_t 
skynet_handle_findname(const char * name) {
	struct handle_storage *s = H;
	//添加读锁
	rwlock_rlock(&s->lock);

	uint32_t handle = 0;

	int begin = 0;
	int end = s->name_count - 1;
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name);
		if (c==0) {
			handle = n->handle;
			break;
		}
		if (c<0) {
			begin = mid + 1;
		} else {
			end = mid - 1;
		}
	}
	//解开读锁
	rwlock_runlock(&s->lock);
	//如果找到了返回handle值,如果找不到返回0
	return handle;
}
//将handle和name 插入到名字空间中
static void
_insert_name_before(struct handle_storage *s, char *name, uint32_t handle, int before) {
	//如果名字空间的数量大于容量了,那么进行动态扩容
	if (s->name_count >= s->name_cap) {
		s->name_cap *= 2;
		assert(s->name_cap <= MAX_SLOT_SIZE);
		struct handle_name * n = skynet_malloc(s->name_cap * sizeof(struct handle_name));
		int i;
		for (i=0;i<before;i++) {
			n[i] = s->name[i];
		}
		for (i=before;i<s->name_count;i++) {
			n[i+1] = s->name[i];
		}
		skynet_free(s->name);
		s->name = n;
	} else {
		int i;
		for (i=s->name_count;i>before;i--) {
			s->name[i] = s->name[i-1];
		}
	}
	//将name 和handle放入名字空间中绑定
	s->name[before].name = name;
	s->name[before].handle = handle;
	s->name_count ++;
}

static const char *
_insert_name(struct handle_storage *s, const char * name, uint32_t handle) {
	int begin = 0;
	int end = s->name_count - 1;
	/*
		strcmp() 用来比较字符串（区分大小写），其原型为：
	    int strcmp(const char *s1, const char *s2);
	*/
	//如果名字空间不空则进入循环
	//二分查询  如果名字存在则返回空,否则按顺序插入到名字空间中
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name);
		if (c==0) {
			return NULL;
		}
		if (c<0) {
			begin = mid + 1;
		} else {
			end = mid - 1;
		}
	}
	//对name进行深拷贝并赋值给result
	char * result = skynet_strdup(name);

	_insert_name_before(s, result, handle, begin);

	return result;
}
//将handle和name进行绑定
const char * 
skynet_handle_namehandle(uint32_t handle, const char *name) {
	//写加锁
	rwlock_wlock(&H->lock);

	const char * ret = _insert_name(H, name, handle);
	//写解锁
	rwlock_wunlock(&H->lock);

	return ret;
}
//初始化 handle_storage
void 
skynet_handle_init(int harbor) {
	assert(H==NULL);
	struct handle_storage * s = skynet_malloc(sizeof(*H));
	//初始化槽大小为4
	s->slot_size = DEFAULT_SLOT_SIZE;
	//申请槽空间
	s->slot = skynet_malloc(s->slot_size * sizeof(struct skynet_context *));
	//初始化槽空间
	memset(s->slot, 0, s->slot_size * sizeof(struct skynet_context *));
	//初始化读写锁
	rwlock_init(&s->lock);
	/*
		harbor & 0xff  取harbor的最后8位 然后左移24位
		4个字节32位:
		最后的位序为:  xxxx xxxx 0000 0000 0000 0000 0000 0000
	*/
	// reserve 0 for system
	s->harbor = (uint32_t) (harbor & 0xff) << HANDLE_REMOTE_SHIFT;
	//handle_index 从1开始生成
	s->handle_index = 1;
	//name空间的容量初始化为2
	s->name_cap = 2;
	//name空间的大小
	s->name_count = 0;
	//name空间申请大小
	s->name = skynet_malloc(s->name_cap * sizeof(struct handle_name));
	//初始化静态handle_storage
	H = s;

	// Don't need to free H
}

