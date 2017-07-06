#include "skynet.h"

#include "skynet_timer.h"
#include "skynet_mq.h"
#include "skynet_server.h"
#include "skynet_handle.h"
#include "spinlock.h"

#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#if defined(__APPLE__)
#include <sys/time.h>
#include <mach/task.h>
#include <mach/mach.h>
#endif

typedef void (*timer_execute_func)(void *ud,void *arg);

#define TIME_NEAR_SHIFT 8
#define TIME_NEAR (1 << TIME_NEAR_SHIFT)		//256
#define TIME_LEVEL_SHIFT 6
#define TIME_LEVEL (1 << TIME_LEVEL_SHIFT)		//64
#define TIME_NEAR_MASK (TIME_NEAR-1)			//255
#define TIME_LEVEL_MASK (TIME_LEVEL-1)			//63

struct timer_event {
	uint32_t handle;
	int session;
};

struct timer_node {
	struct timer_node *next;
	uint32_t expire;
};

struct link_list {
	struct timer_node head;
	struct timer_node *tail;
};

struct timer {
	struct link_list near[TIME_NEAR];	//最外层刻度  256刻度轮盘
	struct link_list t[4][TIME_LEVEL];  //内层刻度
	struct spinlock lock;
	uint32_t time;
	uint32_t starttime;
	uint64_t current;
	uint64_t current_point;
};

static struct timer * TI = NULL;
//移除头结点并返回
static inline struct timer_node *
link_clear(struct link_list *list) {
	struct timer_node * ret = list->head.next;
	list->head.next = 0;
	list->tail = &(list->head);

	return ret;
}

static inline void
link(struct link_list *list,struct timer_node *node) {
	list->tail->next = node;
	list->tail = node;
	node->next=0;
}
/*
	时间轮的实现。按8/6/6/6/6/分成5个轮盘部分，也就是有5个时钟，
	这种分层方法的空间复杂度变为 256+64+64+64+64= 512个槽，
	支持注册最长时间的tick是 256*64*64*64*64=2^32。
*/
static void
add_node(struct timer *T,struct timer_node *node) {
	//失效时间即tick触发的时间
	uint32_t time=node->expire;
	//当前时间
	uint32_t current_time=T->time;  
	//将time和current_time的低8位置1,判断失效时间点是否在本轮时间刻度内触发
	if ((time|TIME_NEAR_MASK)==(current_time|TIME_NEAR_MASK)) {
		//获取time的低8位,找到time对应的刻度 安装事件
		link(&T->near[time&TIME_NEAR_MASK],node);
	} else {//如果不在本轮时间内触发则缓存下来
		//256 左移6位 => 内圈的64刻度盘
		int i;
		uint32_t mask=TIME_NEAR << TIME_LEVEL_SHIFT;
		for (i=0;i<3;i++) {
			//找出该时间所在的时间刻度
			if ((time|(mask-1))==(current_time|(mask-1))) {
				break;
			}
			mask <<= TIME_LEVEL_SHIFT;
		}
		//在该刻度上安装事件
		link(&T->t[i][((time>>(TIME_NEAR_SHIFT + i*TIME_LEVEL_SHIFT)) & TIME_LEVEL_MASK)],node);	
	}
}

static void
timer_add(struct timer *T,void *arg,size_t sz,int time) {
	struct timer_node *node = (struct timer_node *)skynet_malloc(sizeof(*node)+sz);
	memcpy(node+1,arg,sz);

	SPIN_LOCK(T);

	node->expire=time+T->time;
	add_node(T,node);

	SPIN_UNLOCK(T);
}

static void
move_list(struct timer *T, int level, int idx) {
	struct timer_node *current = link_clear(&T->t[level][idx]);
	while (current) {
		struct timer_node *temp=current->next;
		add_node(T,current);
		current=temp;
	}
}

static void
timer_shift(struct timer *T) {
	int mask = TIME_NEAR;
	// 获取下一刻度 并将当前刻度转到下一刻度
	uint32_t ct = ++T->time;   
	//如果下一刻度等于0,说明int32的最大值到了,而时间轮8|6|6|6|6 的最大值也是2^32 所以如果等于下一个time = 0 说明走到了2^32=>即将和刻度0重合 
	if (ct == 0) {
		//找到内层的刻度,将最内层刻度为0的事件 添加到外层刻度
		move_list(T, 3, 0);
	} else {
		//右移动8位,则低6位位内层刻度
		uint32_t time = ct >> TIME_NEAR_SHIFT;
		int i=0;
		//如果最外层刻度走到了0(意味着外层已经走了一圈了,需要从内层某个刻度拉出来一圈放到外层)
		while ((ct & (mask-1))==0) {
			//取内层刻度的值
			int idx=time & TIME_LEVEL_MASK;
			//如果内层刻度没有走到0,则将内层刻度拉出来放到外层
			//循环的跳出条件为:必须有至少一个刻度盘是有值的,有个特殊情况 所有刻度都为0的情况,即是ct = 0的时候特殊处理↑↑↑
			if (idx!=0) {
				move_list(T, i, idx);
				break;				
			}
			// => 1111 1111 0000 00 => (-1) => 0000 0000 1111 11
			mask <<= TIME_LEVEL_SHIFT;
			//计算更内圈刻度
			time >>= TIME_LEVEL_SHIFT;
			++i;
		}
	}
}
//触发时间回调
static inline void
dispatch_list(struct timer_node *current) {
	do {
		struct timer_event * event = (struct timer_event *)(current+1);
		struct skynet_message message;
		message.source = 0;
		message.session = event->session;
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;

		skynet_context_push(event->handle, &message);
		
		struct timer_node * temp = current;
		current=current->next;
		skynet_free(temp);	
	} while (current);
}

static inline void
timer_execute(struct timer *T) {
	//取出来最外层刻度数 
	int idx = T->time & TIME_NEAR_MASK; //<=> T->time % (TIME_NEAR_MASK + 1)
	//判断该刻度下是否有事件列表,如果有则触发
	while (T->near[idx].head.next) {
		struct timer_node *current = link_clear(&T->near[idx]);
		SPIN_UNLOCK(T);
		// dispatch_list don't need lock T
		dispatch_list(current);
		SPIN_LOCK(T);
	}
}

static void 
timer_update(struct timer *T) {
	//自旋锁
	SPIN_LOCK(T);

	// try to dispatch timeout 0 (rare condition)
	timer_execute(T);

	// shift time first, and then dispatch timer message
	timer_shift(T);

	timer_execute(T);
	//解开自旋锁
	SPIN_UNLOCK(T);
}

static struct timer *
timer_create_timer() {
	struct timer *r=(struct timer *)skynet_malloc(sizeof(struct timer));
	memset(r,0,sizeof(*r));

	int i,j;
	//清理最外层的插槽事件
	for (i=0;i<TIME_NEAR;i++) {
		link_clear(&r->near[i]);
	}
	//清理内层的插槽事件
	for (i=0;i<4;i++) {
		for (j=0;j<TIME_LEVEL;j++) {
			link_clear(&r->t[i][j]);
		}
	}

	SPIN_INIT(r)

	r->current = 0;

	return r;
}

int
skynet_timeout(uint32_t handle, int time, int session) {
	if (time <= 0) {
		struct skynet_message message;
		message.source = 0;
		message.session = session;
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;

		if (skynet_context_push(handle, &message)) {
			return -1;
		}
	} else {
		struct timer_event event;
		event.handle = handle;
		event.session = session;
		timer_add(TI, &event, sizeof(event), time);
	}

	return session;
}
//获取当前系统的格林威治时间(单位1/100 s)
// centisecond: 1/100 second
static void
systime(uint32_t *sec, uint32_t *cs) {
#if !defined(__APPLE__)
	struct timespec ti;
	//CLOCK_REALTIME:系统实时时间,随系统实时时间改变而改变,即从UTC1970-1-1 0:0:0开始计时(精度纳秒)
	//tv_sec; /* 秒*/   tv_nsec; /* 纳秒*/
	clock_gettime(CLOCK_REALTIME, &ti);
	*sec = (uint32_t)ti.tv_sec;
	*cs = (uint32_t)(ti.tv_nsec / 10000000);
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);
	*sec = tv.tv_sec;
	*cs = tv.tv_usec / 10000;
#endif
}

static uint64_t
gettime() {
	uint64_t t;
#if !defined(__APPLE__)
	struct timespec ti;
	//CLOCK_MONOTONIC 系统启动以后流逝的时间，它不受任何系统time-of-day时钟修改的影响
	clock_gettime(CLOCK_MONOTONIC, &ti);
	t = (uint64_t)ti.tv_sec * 100;
	t += ti.tv_nsec / 10000000;
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);
	t = (uint64_t)tv.tv_sec * 100;
	t += tv.tv_usec / 10000;
#endif
	return t;
}
//调度时间线程
void
skynet_updatetime(void) {
	uint64_t cp = gettime();
	//current_point 为系统启动后流逝的时间,如果cp比记录的小,说明往前修改过时间
	if(cp < TI->current_point) {
		skynet_error(NULL, "time diff error: change from %lld to %lld", cp, TI->current_point);
		TI->current_point = cp;
	} else if (cp != TI->current_point) { 
		uint32_t diff = (uint32_t)(cp - TI->current_point);
		TI->current_point = cp;
		TI->current += diff;
		//timer_update的单位是0.01s  因为diff的单位是1/100 所以每隔1/100s才会触发一次timer_update
		//如果大于等于 则将中间的时间刻度事件(如果有的话)触发
		int i;
		for (i=0;i<diff;i++) {
			timer_update(TI);
		}
	}
}

uint32_t
skynet_starttime(void) {
	return TI->starttime;
}

uint64_t 
skynet_now(void) {
	return TI->current;
}

void 
skynet_timer_init(void) {
	TI = timer_create_timer();
	uint32_t current = 0;
	//start_time以s为单位 系统的开启时间
	systime(&TI->starttime, &current);
	//系统开始之后经过的时间 
	TI->current = current;
	//current_point 为当前系统启动以后的流逝时间
	TI->current_point = gettime();
}

// for profile

#define NANOSEC 1000000000
#define MICROSEC 1000000

uint64_t
skynet_thread_time(void) {
#if  !defined(__APPLE__)
	struct timespec ti;
	clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ti);

	return (uint64_t)ti.tv_sec * MICROSEC + (uint64_t)ti.tv_nsec / (NANOSEC / MICROSEC);
#else
	struct task_thread_times_info aTaskInfo;
	mach_msg_type_number_t aTaskInfoCount = TASK_THREAD_TIMES_INFO_COUNT;
	if (KERN_SUCCESS != task_info(mach_task_self(), TASK_THREAD_TIMES_INFO, (task_info_t )&aTaskInfo, &aTaskInfoCount)) {
		return 0;
	}

	return (uint64_t)(aTaskInfo.user_time.seconds) + (uint64_t)aTaskInfo.user_time.microseconds;
#endif
}
