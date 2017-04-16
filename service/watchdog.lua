local skynet = require "skynet"
local netpack = require "netpack"
local protobuf = require "protobuf"
local CMD = {}
local SOCKET = {}
local gate
local agent = {}

function SOCKET.open(fd, ipaddr)
    skynet.error("New client from : " .. ipaddr)
    -- agent[fd] = skynet.newservice("agent")
    -- skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })

    protobuf.register_file("proto/msg.pb")

    local t = protobuf.encode("C2GS", {session=10})
    local msg = protobuf.decode2("C2GS", t)
    print("=============")
    for i,v in pairs(msg) do
        print(i,v)
    end
    print("=============")

end

local function close_agent(fd)
    local a = agent[fd]
    agent[fd] = nil
    if a then
        skynet.call(gate, "lua", "kick", fd)
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
    print("socket close",fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
    print("SOCKET.data =>",msg)
end

function CMD.start(conf)
    --开启gate网关服务,监控外部网络连接
    skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
    close_agent(fd)
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

    gate = skynet.newservice("gate")
end)
