local skynet = require "skynet"
local protobuf = require "protobuf"
local watchdog = require "watchdog"
local ipaddrs = {}
local gate

local command = {}

function command.Init()
    protobuf.register_file(skynet.getenv("protobuf"))
    gate = skynet.newservice("gate")
    watchdog:Init(gate)
end

----------------------------------------------
--SOCKET 消息处理
----------------------------------------------
function command.open(fd, ipaddr)
    local ip = string.match(ipaddr, "([%d.]+):")
    ipaddrs[fd] = ip
    skynet.call(gate, "lua", "accept", fd)
end

function command.close(fd)
    watchdog:SetExpireTime(fd)
end

function command.error(fd, msg)
    watchdog:SetExpireTime(fd)
end

function command.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
    skynet.error("size K bytes havn't send out in fd <> socket warning fd:",fd," size:",size)
end

function command.data(fd, msg)
    if not watchdog:OnReceiveData(fd, msg,ipaddrs[fd]) then
        skynet.call(gate, "lua", "kick", fd)
    end
end
--------------------------------
--外部消息调用
--------------------------------

--开启gate网关服务,监控外部网络连接
function command.start(conf)    
    skynet.call(gate, "lua", "open" , conf)
end

function command.GetAgentByUserId(user_id)
    return watchdog:GetAgentByUserId(user_id)
end

return command
