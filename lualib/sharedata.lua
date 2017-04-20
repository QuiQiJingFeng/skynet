local skynet = require "skynet"
local sd = require "sharedata.corelib"

local service
skynet.init(function()
	service = skynet.uniqueservice "sharedatad"
end)

local sharedata = {}
local cache = setmetatable({}, { __mode = "kv" })

local function monitor(name, obj, cobj)
	local newobj = cobj
	while true do
		newobj = skynet.call(service, "lua", "monitor", name, newobj)
		if newobj == nil then
			break
		end
		sd.update(obj, newobj)
	end
	if cache[name] == obj then
		cache[name] = nil
	end
end
--------------------------
--根据key值查询共享对象
--获取到的共享对象实质上是一个userdata
--但是它lua VM通过自定义table的指针访问自定义table中的内容。
--corelib.lua 中定义了userdata的元表。
--元表中包含 __index、__len、__pairs 等方法，使得访问userdata像访问原有数据一样。
--------------------------
function sharedata.query(name)
	if cache[name] then
		return cache[name]
	end
	
	local obj = skynet.call(service, "lua", "query", name)
	local r = sd.box(obj)
	skynet.send(service, "lua", "confirm" , obj)
	skynet.fork(monitor,name, r, obj)
	cache[name] = r
	return r
end
--------------------------
--创建一个共享数据对象
--------------------------
function sharedata.new(name, v, ...)
	skynet.call(service, "lua", "new", name, v, ...)
end
--------------------------
--更新共享对象,如果不存在则创建
--------------------------
function sharedata.update(name, v, ...)
	skynet.call(service, "lua", "update", name, v, ...)
end
--------------------------
--删除一个共享对象
--------------------------
function sharedata.delete(name)
	skynet.call(service, "lua", "delete", name)
end
--------------------------
--清理旧的数据
--如果你持有一个代理对象，但在更新数据后没有访问里面的数据，那么该代理对象会一直持有老版本的数据直到第一次访问。
--这个行为的副作用是：老版本的 C 对象会一直占用内存。
--如果你需要频繁更新数据，那么，为了加快内存回收，可以通知持有代理对象的服务在更新后，主动调用 sharedata.flush() 。
--------------------------
function sharedata.flush()
	for name, obj in pairs(cache) do
		sd.flush(obj)
	end
	collectgarbage()
end
--------------------------
--获取一个共享对象的深拷贝实例
--------------------------
function sharedata.deepcopy(name, ...)
	if cache[name] then
		local cobj = cache[name].__obj
		return sd.copy(cobj, ...)
	end

	local cobj = skynet.call(service, "lua", "query", name)
	local ret = sd.copy(cobj, ...)
	skynet.send(service, "lua", "confirm" , cobj)
	return ret
end

return sharedata

--REDEME:FYD  共享数据
--[[
	对于我们skynet体系来说，有一个隐含的最大的问题，就是在不同的service之间分享数据成本比较高。
	例如游戏中的表格数据、配置数据。这些数据在整个服务器的运行过程中基本不会被改变（或是非常少的需要改变），
	但是数据量又非常的大，查询起来非常的频繁，基本所有的service都需要使用。
	对于这样的静态数据我们可能会有两种做法：
	1、制作一个中心数据服务，所有其他服务需要静态数据时向这个服务器发送message去查询，
	2、然后等待返回让所有需要静态数据的服务，自己在启动的时候装载这些数据

	这两种做法都有比较大的损失。
	第一种虽然内存只占用了一份，但是这样大量的查询请求会出现在shield的消息队列中，整个服务器的性能会有损失。
	第二种严重的浪费了内存，而且如果想要做这些静态内容的热更新变得基本没有可能。

	功能
	我们的 sharedata 服务就是用来解决这样的问题，它可以存储一张 lua 的 table ，并使用同一块C的内存来存储这些数据。
	当其他服务需要这些数据的时候，只是简单地获取这个C的指针，然后再通过 Lua 的代码来读取它，由于其他服务只是读取，
	所以虽然存在多线程同时访问的情况，但是只读的数据依然不需要上锁，所以在性能和空间两方面都有比较大的提升，
	建议大家对于不经常更新的数据使用 sharedata 来处理。

	sharedata 是基于共享内存工作的，且访问共享对象内的数据并不会阻塞当前的服务。所以可以保证不错的性能，并节省大量的内存。

	sharedata 的缺点是更新一次的成本非常大，所以不适合做服务间的数据交换(频繁更新)
--]]