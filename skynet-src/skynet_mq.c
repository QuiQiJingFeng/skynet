#include "skynet.h"
#include "skynet_mq.h"
#include "skynet_handle.h"
#include "spinlock.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
//消息队列的初始大小
#define DEFAULT_QUEUE_SIZE 64
#define MAX_GLOBAL_MQ 0x10000

// 0 means mq is not in global mq.
// 1 means mq is in global mq , or the message is dispatching.
//是否在全局队列中
#define MQ_IN_GLOBAL 1
#define MQ_OVERLOAD 1024			//消息队列的初始阈值

struct message_queue {
	struct spinlock lock;			//消息队列的锁
	uint32_t handle;				//消息队列的句柄
	int cap;						//capcity skynet_message的容量
	int head;						//消息队列头结点
	int tail;						//消息队列尾结点
	int release;
	int in_global;					//是否在全局队列中（1为在,2为不在）
	int overload;					//
	int overload_threshold;     	//过载阀值 默认为1024
	struct skynet_message *queue;	//消息队列内存块地址	
	struct message_queue *next;		//指向下一个消息队列结点(作为全局消息队列的结点存在)	
};
//全局消息队列
struct global_queue {
	struct message_queue *head; 	//全局消息队列头结点(指向一个消息队列结点)
	struct message_queue *tail;		//全局消息队列尾结点
	struct spinlock lock; 			//全局消息队列的锁
};
//声明一个静态的全局消息队列Q
static struct global_queue *Q = NULL;
//将一个消息队列添加到全局消息队列中
void 
skynet_globalmq_push(struct message_queue * queue) {
	struct global_queue *q= Q;
	//对全局消息队列加锁
	SPIN_LOCK(q)
	//加入全局消息的队列必须为空,也就是说只能是单个结点加进来,不能直接加进来一个链表
	assert(queue->next == NULL);
	//将消息队列挂载到全局消息队列的末尾
	if(q->tail) {
		q->tail->next = queue;
		q->tail = queue;
	} else {
		q->head = q->tail = queue;
	}
	//对全局消息队列解锁
	SPIN_UNLOCK(q)
}
//将消息队列弹出全局消息队列
struct message_queue * 
skynet_globalmq_pop() {
	struct global_queue *q = Q;
	//对全局消息队列加锁
	SPIN_LOCK(q)
	struct message_queue *mq = q->head;
	//取出消息队列的头结点
	if(mq) {
		q->head = mq->next;
		if(q->head == NULL) {
			assert(mq == q->tail);
			q->tail = NULL;
		}
		mq->next = NULL;
	}
	//对全局消息队列解锁
	SPIN_UNLOCK(q)

	return mq;
}
//创建一个消息队列
struct message_queue * 
skynet_mq_create(uint32_t handle) {
	struct message_queue *q = skynet_malloc(sizeof(*q));
	q->handle = handle;
	//初始化消息队列的长度为64
	q->cap = DEFAULT_QUEUE_SIZE;
	//初始化头结点索引、尾结点索引
	q->head = 0;		
	q->tail = 0;
	//初始化消息队列的锁spinlock
	SPIN_INIT(q)
	// When the queue is create (always between service create and service init) ,
	// set in_global flag to avoid push it to global queue .
	// If the service init success, skynet_context_new will call skynet_mq_push to push it to global queue.
	//设置in_global为1 标记将要被加入到全局消息队列中
	q->in_global = MQ_IN_GLOBAL;
	q->release = 0;
	//是否超过阈值
	q->overload = 0;
	//队列的临界值设置为1024(注意:这里并不是最大值,当超过临界值的时候会给一个警告)
	q->overload_threshold = MQ_OVERLOAD;
	//申请消息队列的内存块,并将指针赋值给queue
	q->queue = skynet_malloc(sizeof(struct skynet_message) * q->cap);
	//作为全局消息队列的一个结点,指向下一个节点的地址初始化为NULL
	q->next = NULL;

	return q;
}
//释放消息队列的内存
static void 
_release(struct message_queue *q) {
	//销毁的时候队列中不能有消息,如果有消息就说明bug了
	assert(q->next == NULL);
	SPIN_DESTROY(q)
	//释放消息队列的内存块
	skynet_free(q->queue);
	//释放消息队列结构体
	skynet_free(q);
}
//获取消息队列的句柄
uint32_t 
skynet_mq_handle(struct message_queue *q) {
	return q->handle;
}
//获取消息队列的长度
int
skynet_mq_length(struct message_queue *q) {
	int head, tail,cap;
	//对消息队列加锁  为了保证读取的几个变量的一致性,这里需要加锁
	SPIN_LOCK(q)
	head = q->head;
	tail = q->tail;
	cap = q->cap;
	//对消息队列解锁
	SPIN_UNLOCK(q)
	//返回队列长度
	if (head <= tail) {
		return tail - head;
	}
	return tail + cap - head;
}
//检测队列是否超过阈值,如果超过则重置阈值
int
skynet_mq_overload(struct message_queue *q) {
	//如果队列已经超过阈值 overload !=0
	if (q->overload) {
		int overload = q->overload;
		//重置overload为0,同时返回是否超过阈值
		q->overload = 0;
		return overload;
	} 
	return 0;
}
//弹出消息队列的消息(消息队列的实现形式为循环链表)
int
skynet_mq_pop(struct message_queue *q, struct skynet_message *message) {
	int ret = 1;
	//对消息队列进行加锁
	SPIN_LOCK(q)
	//如果队列中的消息数量不为空
	if (q->head != q->tail) {
		//取出队列的头结点赋值给message结构体, head之后会自加1
		//和全局列表的head不同，这里的head只是一个queue内存块中的索引
		*message = q->queue[q->head++];
		ret = 0;
		int head = q->head;
		int tail = q->tail;
		int cap = q->cap;
		//如果弹出后发现下一个head的位置大于容量,则将head设置为0
		if (head >= cap) {
			q->head = head = 0;
		}
		//因为是循环链表,所以tail-head有可能为负数
		int length = tail - head;
		if (length < 0) {
			length += cap;
		}
		//如果当前队列的剩余消息数量大于阈值
		while (length > q->overload_threshold) {
			//标记被超过的阈值的大小
			q->overload = length;
			//将阈值设置为两倍
			q->overload_threshold *= 2;
		}
	} else {
		// reset overload_threshold when queue is empty
		q->overload_threshold = MQ_OVERLOAD;
	}
	//如果队列的消息为空,则将队列标记移除全局队列
	if (ret) {
		q->in_global = 0;
	}
	
	SPIN_UNLOCK(q)

	return ret;
}

static void
expand_queue(struct message_queue *q) {
	//将队列的容量扩大两倍
	struct skynet_message *new_queue = skynet_malloc(sizeof(struct skynet_message) * q->cap * 2);
	//然后将旧的队列中的消息赋值到新的队列中区
	int i;
	for (i=0;i<q->cap;i++) {
		new_queue[i] = q->queue[(q->head + i) % q->cap];
	}
	q->head = 0;
	q->tail = q->cap;
	q->cap *= 2;
	//释放旧的队列内存块地址
	skynet_free(q->queue);
	//赋值新的队列内存块地址
	q->queue = new_queue;
}
//将消息压入消息队列(消息队列的实现形式为循环链表)
void 
skynet_mq_push(struct message_queue *q, struct skynet_message *message) {
	assert(message);
	//对消息队列进行加锁
	SPIN_LOCK(q)

	q->queue[q->tail] = *message;
	if (++ q->tail >= q->cap) {
		q->tail = 0;
	}
	//当头结点和尾结点相同意味着队列达到最大了，需要扩容
	if (q->head == q->tail) {
		expand_queue(q);
	}
	//如果该队列不在全局消息队列中,标记为需要放入全局消息队列
	if (q->in_global == 0) {
		q->in_global = MQ_IN_GLOBAL;
		//压入全局消息队列
		skynet_globalmq_push(q);
	}
	//对消息队列进行解锁
	SPIN_UNLOCK(q)
}
//skynet_mq初始化,初始化静态全局消息队列
void 
skynet_mq_init() {
	struct global_queue *q = skynet_malloc(sizeof(*q));
	memset(q,0,sizeof(*q));
	//初始化全局消息队列的锁
	SPIN_INIT(q);
	Q=q;
}
//标记销毁  release为1代表需要销毁
void 
skynet_mq_mark_release(struct message_queue *q) {
	SPIN_LOCK(q)
	assert(q->release == 0);
	q->release = 1;
	//如果不在全局队列则将其加入到全局队列等待被销毁
	if (q->in_global != MQ_IN_GLOBAL) {
		skynet_globalmq_push(q);
	}
	SPIN_UNLOCK(q)
}
//销毁队列
static void
_drop_queue(struct message_queue *q, message_drop drop_func, void *ud) {
	struct skynet_message msg;
	//循环弹出消息队列并调用drop_func将消息传递过去  知道队列为空
	while(!skynet_mq_pop(q, &msg)) {
		drop_func(&msg, ud);
	}
	//释放消息队列所占的内存
	_release(q);
}

void 
skynet_mq_release(struct message_queue *q, message_drop drop_func, void *ud) {
	SPIN_LOCK(q)
	//队列是否有销毁标记 release为1代表需要销毁
	if (q->release) {
		SPIN_UNLOCK(q)
		_drop_queue(q, drop_func, ud);
	} else {
		//压入全局消息队列
		skynet_globalmq_push(q);
		SPIN_UNLOCK(q)
	}
}
