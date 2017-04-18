local shield = require "shield"
local pbc = require "protobuf"
local netpack = require "netpack"
local socket = require "socket"
local cjson = require "cjson"
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

local TIME_ZONE = tonumber(shield.getenv("time_zone"))

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
    id = shield.PTYPE_CLIENT,
    unpack = function (msg, sz)
        return pbc.decode("C2GS", msg, sz)
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
            local buff, sz = netpack.pack(pbc.encode("GS2C", {session = user_info.session_id, heart_beat_ret = {}}))
            socket.write(user_info.client_fd, buff, sz)
            return
        end

        local succ, ret = queue(function 
                local succ, proto, send_msg = xpcall(msg_handler.Dispatch, debug.traceback, msg_handler, msg_name, data)

                if succ and proto then
                    local succ, err = pcall(user_info.ResponseClient, user_info, proto, send_msg, true)
                    if not succ then
                        shield.error(err)
                        user_info:ResponseClient("error_ret", {}, true)
                    end
                elseif proto then
                    shield.error(user_info.user_id)
                    shield.error(proto)
                    user_info:ResponseClient("error_ret", {}, true)
                end
            end)
    end
})

--玩家第一次登录
function CMD.Start(gate,fd,ip,user_id,login_msg)
    --转发fd的消息到本服务
    local forward_ret = skynet.call(gate, "lua", "forward", fd)
    if not forward_ret or not user_id then
        shield.error("forward error: user_id="..user_id.."ip="..ip.."fd="..fd)
        return 0
    end
    --加载玩家数据
    user_info:LoadFromDb(user_id)

    user_info:SetSocket(fd, ip)

    user_info.device_id = login_msg.device_id
    user_info.locale = login_msg.locale
    user_info.platform_uid = login_msg.user
    user_info.platform = login_msg.platform

    gate = gate

    return 1
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

    config_manager = require "config_manager"
    config_manager:Init()

    constants = config_manager.constants

end)
