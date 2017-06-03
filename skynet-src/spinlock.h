#ifndef SKYNET_SPINLOCK_H
#define SKYNET_SPINLOCK_H

#define SPIN_INIT(q) spinlock_init(&(q)->lock);
#define SPIN_LOCK(q) spinlock_lock(&(q)->lock);
#define SPIN_UNLOCK(q) spinlock_unlock(&(q)->lock);
#define SPIN_DESTROY(q) spinlock_destroy(&(q)->lock);
//如果没有定义pthread 锁 那么使用下面的
#ifndef USE_PTHREAD_LOCK

struct spinlock {
	int lock;
};
//初始化spinlock state 0 代表无锁
static inline void
spinlock_init(struct spinlock *lock) {
	lock->lock = 0;
}
/*
	gcc提供的用于原子操作的方法：将*ptr设为value并返回*ptr操作之前的值。
	type __sync_lock_test_and_set (type *ptr, type value, ...)
*/
/*
	将lock的 state状态设置为锁定状态,循环锁定，直到锁释放为止 
	百科:http://baike.baidu.com/item/%E8%87%AA%E6%97%8B%E9%94%81
*/
static inline void
spinlock_lock(struct spinlock *lock) {
	while (__sync_lock_test_and_set(&lock->lock,1)) {}
}
//尝试增加锁状态,并返回之是否成功锁定,因为如果之前为0代表无锁状态
static inline int
spinlock_trylock(struct spinlock *lock) {
	return __sync_lock_test_and_set(&lock->lock,1) == 0;
}
/*
	void __sync_lock_release (type *ptr, ...)
     将*ptr置0
*/
//接触锁定状态
static inline void
spinlock_unlock(struct spinlock *lock) {
	__sync_lock_release(&lock->lock);
}
//听别人说(void) lock是为了避免警告,不太理解  先标记下
static inline void
spinlock_destroy(struct spinlock *lock) {
	(void) lock;
}

#else
//如果定义了USE_PTHREAD_LOCK 那么使用下面的pthread库
#include <pthread.h>

// we use mutex instead of spinlock for some reason
// you can also replace to pthread_spinlock

struct spinlock {
	pthread_mutex_t lock;
};
//初始化pthread库
static inline void
spinlock_init(struct spinlock *lock) {
	pthread_mutex_init(&lock->lock, NULL);
}

static inline void
spinlock_lock(struct spinlock *lock) {
	pthread_mutex_lock(&lock->lock);
}

static inline int
spinlock_trylock(struct spinlock *lock) {
	return pthread_mutex_trylock(&lock->lock) == 0;
}

static inline void
spinlock_unlock(struct spinlock *lock) {
	pthread_mutex_unlock(&lock->lock);
}

static inline void
spinlock_destroy(struct spinlock *lock) {
	pthread_mutex_destroy(&lock->lock);
}

#endif

#endif
