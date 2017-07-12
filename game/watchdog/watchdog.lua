local skynet = require "skynet"
local agent_manager = require "agent_manager"
local watchdog = {}
local CMD = {}
local SOCKET = {}
watchdog.SOCKET = SOCKET
watchdog.CMD = CMD
local gate
local ipaddrs
function watchdog:Init()
    gate = agent_manager:Init()
end

----------------------------------------------
--SOCKET 消息处理
----------------------------------------------

function SOCKET.open(fd, ipaddr)
    local ip = string.match(ipaddr, "([%d.]+):")
    skynet.call(gate, "lua", "accept", fd)
end

function SOCKET.close(fd)
    agent_manager:SetExpireTime(fd)
end

function SOCKET.error(fd, msg)
    agent_manager:SetExpireTime(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
    skynet.error("size K bytes havn't send out in fd <> socket warning fd:",fd," size:",size)
end

function SOCKET.data(fd, msg)
    if not agent_manager:OnReceiveData(fd, msg,ipaddrs[fd]) then
        skynet.call(gate, "lua", "kick", fd)
    end
end

--------------------------------
--外部消息调用
--------------------------------

--开启gate网关服务,监控外部网络连接
function CMD.start(conf)    
    skynet.call(gate, "lua", "open" , conf)
end

return watchdog
