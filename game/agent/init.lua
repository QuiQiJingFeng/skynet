local skynet = require "skynet"
local protobuf = require "protobuf"
local netpack = require "netpack"
local socket = require "socket"
local md5 = require "md5"
local cls = require "skynet.queue"
local queue = cls()
local config_manager
local msg_handler
local user_info
local reward_center

local constants
local CMD = {}
local AGENT_OP = {}

local TIME_ZONE = tonumber(skynet.getenv("time_zone"))

local gate

setmetatable(AGENT_OP, {
    __call = function(t, func_name, ...)
         
        local func = AGENT_OP[func_name]
        local succ, ret = queue(func,...)
        --执行错误在此结束协程, 阻止ret返回
        if not succ then
            assert(false)
        end

        return ret
    end
})

-- gate will use client protocol for client's data
skynet.register_protocol( {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function (msg, sz)
        return protobuf.decode("C2GS", msg, sz)
    end,

    dispatch = function (_, _, msg, pbc_error)

        if pbc_error or not msg then
            print(pbc_error)
            return
        end

        local session
        local msg_name, data

        for k, v in pairs(msg) do
            if k == "session" then
                session = v
            else
                msg_name = k
                data = v
            end
        end

        if not msg_name then
            return
        end

        if msg_name == "heart_beat" then
            local buff, sz = netpack.pack(protobuf.encode("GS2C", {session = user_info.session_id, heart_beat_ret = {}}))
            socket.write(user_info.client_fd, buff, sz)
            return
        end  
    end
})

--玩家第一次登录
function CMD.Start(gate,fd,ip,user_id,login_msg)
    --转发fd的消息到本服务
    skynet.send(gate, "lua", "forward", fd)
    gate = gate
    --加载玩家数据
    user_info:LoadFromDb(user_id)
    user_info:InitData(login_msg,fd, ip)

    --是否需要创建角色
    if not user_info:IsNeedCreateRole() then
        user_info:ResponseClient("login_ret", { result = "create_leader", server_time = skynet.time(),
                                                user_id = user_id, time_zone = TIME_ZONE ,client_ip = ip}, true)
    else
        user_info:ResponseClient("login_ret", { result = "success", server_time = skynet.time(),
                                                user_id = user_id, time_zone = TIME_ZONE,client_ip = ip}, true)
    end

    return "success"
end




skynet.start(function()
    skynet.dispatch("lua", function(session, service_address, cmd, ...)
        local ret
        
        if AGENT_OP[cmd] then
            ret = AGENT_OP(cmd, ...)
        else
            local f = assert(CMD[cmd])
            ret = f(...)
        end

        if session > 0 then
            skynet.ret(skynet.pack(ret))
        end
    end)
    protobuf.register_file(skynet.getenv("protobuf"))

    user_info = require "user_info"
    user_info:Init(tonumber(skynet.getenv("server_id")))
    config_manager = require "config_manager"
    print("ddddddgggggggggggg")
    config_manager:Init()

    constants = config_manager.constants

end)
