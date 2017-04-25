local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local netpack = require "netpack"
local sharedata = require "sharedata"
local protobuf = require "protobuf"
local agent_manager = require "agent_manager"
local CMD = {}
local SOCKET = {}
local ipaddrs = {}
local gate

function SOCKET.open(fd, ipaddr)
    local ip = string.match(ipaddr, "([%d.]+):")
    ipaddrs[fd] = ip
    skynet.call(gate, "lua", "accept", fd)
end

function SOCKET.close(fd)
    agent_manager:SetExpireTime(fd)
end

function SOCKET.error(fd, msg)
    skynet.error("fd:",fd," msg:",msg)
    agent_manager:SetExpireTime(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
    skynet.error("size K bytes havn't send out in fd <> socket warning fd:",fd," size:",size)
end

function SOCKET.data(fd, msg)
    if not agent_manager:onReceiveData(fd, msg,ipaddrs[fd]) then
        skynet.call(gate, "lua", "kick", fd)
    end
end

--开启gate网关服务,监控外部网络连接
function CMD.start(conf)    
    skynet.call(gate, "lua", "open" , conf)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)
    protobuf.register_file(skynet.getenv("protobuf"))
    gate = skynet.newservice("gate")
    agent_manager:init(gate)

    skynet.register(".watchdog")
end)
