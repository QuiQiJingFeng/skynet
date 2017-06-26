local skynet = require "skynet"
local protobuf = require "protobuf"
local agent_manager = require "agent_manager"
local ipaddrs = {}
local gate

local watchdog = {}
local CMD = {}
local SOCKET = {}
watchdog.SOCKET = SOCKET
watchdog.CMD = CMD

function watchdog:Init()
    protobuf.register_file(skynet.getenv("protobuf"))
    gate = skynet.newservice("gate")
    agent_manager:Init(gate)
end

----------------------------------------------
--SOCKET 消息处理
----------------------------------------------

function SOCKET.open(fd, ipaddr)
    local ip = string.match(ipaddr, "([%d.]+):")
    ipaddrs[fd] = ip
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

function CMD.GetAgentByUserId(user_id)
    return agent_manager:GetAgentByUserId(user_id)
end

return watchdog
