local skynet = require "skynet"
local coroutine = coroutine
local xpcall = xpcall
local traceback = debug.traceback
local table = table

function skynet.queue()
	local current_thread
	local ref = 0
	local thread_queue = {}

	local function xpcall_ret(ok, ...)
		ref = ref - 1
		if ref == 0 then
			current_thread = table.remove(thread_queue,1)
			if current_thread then
				skynet.wakeup(current_thread)
			end
		end
		assert(ok, (...))
		return ...
	end

	return function(f, ...)
		local thread = coroutine.running()
		if current_thread and current_thread ~= thread then
			table.insert(thread_queue, thread)
			skynet.wait()
			assert(ref == 0)	-- current_thread == thread
		end
		current_thread = thread

		ref = ref + 1
		return xpcall_ret(xpcall(f, traceback, ...))
	end
end

return skynet.queue
--REDEME:FYD  处理消息的顺序问题
--[[
	一个 skynet 服务中的一条消息处理中，如果调用了一个阻塞 API ，那么它会被挂起。
	挂起过程中，这个服务可以响应其它消息。
	这很可能造成时序问题，要非常小心处理。
	换句话说，一旦你的消息处理过程有外部请求，那么先到的消息未必比后到的消息先处理完。
	且每个阻塞调用之后，服务的内部状态都未必和调用前的一致（因为别的消息处理过程可能改变状态）。

	使用skynet.queue 模块可以帮助你回避这些伪并发引起的复杂性。

	原理:
		使用闭包来创建一个伪队列，来保证先到的消息先处理完,后到的消息后处理完(服务的状态跟消息处理的先后有关系的时候需要用到)
	举个🌰:
		比如:班里发月饼,领完为止
		如果现在只剩下一个月饼,A和B都去领了。
		A先到了，但是领月饼的过程中,C跟A聊了会天(阻塞调用),聊完之后发现月饼已经被B领走了。。。
		解决:
			如果排队领的话A就能够领到了。
		
		如果在服务器的话,就会出问题。
		导致一个本来应该领到的奖励被别人领走了，
		比如：显示的可以领奖(第XX名奖励),却一直领不了奖励

	example:
		local queue = require "skynet.queue"
		local cs = queue()  -- cs 是一个执行队列

		local CMD = {}

		function CMD.foobar()
		  cs(func1)  -- push func1 into critical section
		end

		function CMD.foo()
		  cs(func2)  -- push func2 into critical section
		end

		比如你实现了这样一个消息分发器，支持 foobar 和 foo 两类消息。
		如果你使用 cs 这个 shield.queue 创建出来的队列。那么在上面的处理流程中，
		func1 和 func2 这两个函数，都不会在执行过程中相互被打断。

		如果你的服务收到多条 foobar 或 foo 消息，一定是处理完一条后，才处理下一条，
		即使 func1 或 func2 中有 shield.call 这类的阻塞调用。
		一旦它们被挂起，新的消息到来后，新的处理流程会被排到 cs 队列尾，
		等待前面的流程执行完毕才会开始。

]]
