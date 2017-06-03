#ifndef SKYNET_MESSAGE_QUEUE_H
#define SKYNET_MESSAGE_QUEUE_H

#include <stdlib.h>
#include <stdint.h>
//skynet 消息结构体
struct skynet_message {
	uint32_t source;	//来源
	int session;		//用来对应请求和回应
	void * data;		//数据指针
	size_t sz;			//数据的大小
};

// type is encoding in skynet_message.sz high 8bit
#define MESSAGE_TYPE_MASK (SIZE_MAX >> 8)
#define MESSAGE_TYPE_SHIFT ((sizeof(size_t)-1) * 8)

struct message_queue;
//将一个消息队列压人全局消息队列中
void skynet_globalmq_push(struct message_queue * queue);
//从全局消息队列中弹出一个消息队列
struct message_queue * skynet_globalmq_pop(void);
//创建一个消息队列
struct message_queue * skynet_mq_create(uint32_t handle);
//标记一个消息队列销毁
void skynet_mq_mark_release(struct message_queue *q);

typedef void (*message_drop)(struct skynet_message *, void *);
//销毁一个消息队列
void skynet_mq_release(struct message_queue *q, message_drop drop_func, void *ud);
//获取一个消息队列的handle
uint32_t skynet_mq_handle(struct message_queue *);
//从消息队列中弹出一个消息,0代表弹出成功
// 0 for success
int skynet_mq_pop(struct message_queue *q, struct skynet_message *message);
//压人一个消息队列
void skynet_mq_push(struct message_queue *q, struct skynet_message *message);
//返回一个消息队列的长度
// return the length of message queue, for debug
int skynet_mq_length(struct message_queue *q);
//检测队列是否超过阈值,如果超过则重置阈值
int skynet_mq_overload(struct message_queue *q);
//skynet_mq初始化
void skynet_mq_init();

#endif
