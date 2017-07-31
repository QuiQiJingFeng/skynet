local skynet = require "skynet"
local protobuf = require "protobuf"
local netpack = require "websocketnetpack"
local socket = require "socket"
local user_info = require "user_info"
local event_dispatcher = require "event_dispatcher"

local command = require "command"
local AGENT_OP = command.AGENT_OP
local CMD = command.CMD

--客户端消息处理
skynet.register_protocol( {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function (msg, sz)
        return protobuf.decode("C2GS", msg, sz)
    end,

    dispatch = function (_, _, msg, pbc_error)
        if pbc_error or not msg then
            skynet.error("PBC_ERROR:",pbc_error)
            return
        end
        if _G["SEASSION_PROCESS"] then
            return
        end
        _G["SEASSION_PROCESS"] = true
        --如果当前在存储,则暂时挂起
        while _G["SAVE_FLAG"] do
            skynet.yield()
        end
        local msg_name,data = next(msg)
        local succ, proto, send_msg = xpcall(event_dispatcher.DispatchEvent, debug.traceback, event_dispatcher, msg_name, data)
        print("FYD===>>>",succ, proto, send_msg)
        if succ and proto then
            local succ, err = pcall(user_info.ResponseClient, user_info, proto, send_msg)
            if not succ then
                skynet.error("RESPONSE_ERROR",err)
                user_info:ResponseClient("error_ret", {})
            end
        elseif proto then
            skynet.error("PROCESS_ERROR:",user_info.user_id)
            skynet.error(proto)
            user_info:ResponseClient("error_ret", {})
        end
        _G["SEASSION_PROCESS"] = false
    end
})

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
    command.Init()
end)
