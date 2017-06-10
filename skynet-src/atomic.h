#ifndef SKYNET_ATOMIC_H
#define SKYNET_ATOMIC_H
/*
	原子操作:
	这个函数提供原子的比较和交换，如果*ptr == oval,就将nval写入*ptr,
	__sync_bool_compare_and_swap(ptr, oval, nval)
*/
#define ATOM_CAS(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
#define ATOM_CAS_POINTER(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
/*
	原子操作:先自加,再返回,返回的是自加以后的值
	__sync_add_and_fetch
*/
#define ATOM_INC(ptr) __sync_add_and_fetch(ptr, 1)
/*
	原子操作:先返回,再自加,返回的是自家之前的值
	__sync_fetch_and_add
*/
#define ATOM_FINC(ptr) __sync_fetch_and_add(ptr, 1)
/*
	原子操作:先乘,再返回,返回的是乘完以后的值
	__sync_sub_and_fetch	
*/
#define ATOM_DEC(ptr) __sync_sub_and_fetch(ptr, 1)
/*
	原子操作:先返回,再乘,返回的是乘之前的值
	__sync_fetch_and_sub	
*/
#define ATOM_FDEC(ptr) __sync_fetch_and_sub(ptr, 1)
#define ATOM_ADD(ptr,n) __sync_add_and_fetch(ptr, n)
#define ATOM_SUB(ptr,n) __sync_sub_and_fetch(ptr, n)
#define ATOM_AND(ptr,n) __sync_and_and_fetch(ptr, n)

#endif
