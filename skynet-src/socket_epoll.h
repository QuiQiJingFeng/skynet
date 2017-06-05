#ifndef poll_socket_epoll_h
#define poll_socket_epoll_h

#include <netdb.h>
#include <unistd.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>

static bool 
sp_invalid(int efd) {
	return efd == -1;
}
/*
	int epoll_create(int size)
	创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大。
	当创建好epoll句柄后，它本身也会占用一个fd值
*/
static int
sp_create() {
	return epoll_create(1024);
}
//关闭epoll句柄
static void
sp_release(int efd) {
	close(efd);
}
/*
	int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)
	epoll的事件注册函数在这里先注册要监听的事件类型
	参数1: epoll句柄
	参数2: 动作，用三个宏来表示：
		EPOLL_CTL_ADD: 注册新的fd到epfd中；
		EPOLL_CTL_MOD: 修改已经注册的fd的监听事件；
		EPOLL_CTL_DEL: 从epfd中删除一个fd
	参数3: 是需要监听的fd
	参数4: 是告诉内核需要监听什么事
		struct epoll_event {
			__uint32_t events; // Epoll events 
			epoll_data_t data; // User data variable 
		};
		events可以是以下几个宏的集合：
		EPOLLIN ：表示对应的文件描述符可以读（包括对端SOCKET正常关闭）；
		EPOLLOUT：表示对应的文件描述符可以写；
		EPOLLPRI：表示对应的文件描述符有紧急的数据可读（这里应该表示有带外数据到来）；
		EPOLLERR：表示对应的文件描述符发生错误；
		EPOLLHUP：表示对应的文件描述符被挂断；
		EPOLLET： 将EPOLL设为边缘触发(Edge Triggered)模式，这是相对于水平触发(Level Triggered)来说的。
		EPOLLONESHOT：只监听一次事件，当监听完这次事件之后，如果还需要继续监听这个socket的话，需要再次把这个socket加入到EPOLL队列里。

*/
static int 
sp_add(int efd, int sock, void *ud) {
	struct epoll_event ev;
	ev.events = EPOLLIN;
	ev.data.ptr = ud;
	if (epoll_ctl(efd, EPOLL_CTL_ADD, sock, &ev) == -1) {
		return 1;
	}
	return 0;
}

static void 
sp_del(int efd, int sock) {
	epoll_ctl(efd, EPOLL_CTL_DEL, sock , NULL);
}

static void 
sp_write(int efd, int sock, void *ud, bool enable) {
	struct epoll_event ev;
	ev.events = EPOLLIN | (enable ? EPOLLOUT : 0);
	ev.data.ptr = ud;
	epoll_ctl(efd, EPOLL_CTL_MOD, sock, &ev);
}
/*
	int epoll_wait epoll_wait() 可以用于等待IO事件。如果当前没有可用的事件，这个函数会阻塞调用线程。
	int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout)
	参数2: events用来从内核得到事件的集合
	参数3: maxevents表示每次能处理的最大事件数  maxevents的值不能大于创建epoll_create()时的size
	参数4: timeout是超时时间（毫秒，0会立即返回，-1将不确定，也有说法说是永久阻塞）。
	该函数返回需要处理的事件数目，如返回0表示已超时。
*/
static int 
sp_wait(int efd, struct event *e, int max) {
	struct epoll_event ev[max];
	int n = epoll_wait(efd , ev, max, -1);
	int i;
	for (i=0;i<n;i++) {
		e[i].s = ev[i].data.ptr;
		unsigned flag = ev[i].events;
		e[i].write = (flag & EPOLLOUT) != 0;
		e[i].read = (flag & EPOLLIN) != 0;
	}

	return n;
}
/*
	int fcntl(int fd, int cmd); 
	int fcntl(int fd, int cmd, long arg); 
	int fcntl(int fd, int cmd, struct flock *lock);
	设置为非阻塞
*/
static void
sp_nonblocking(int fd) {
	//返回fd的文件描述符
	int flag = fcntl(fd, F_GETFL, 0);
	if ( -1 == flag ) {
		return;
	}
	//设置为非阻塞 返回复数则表示设置失败 TODO
	fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

#endif
