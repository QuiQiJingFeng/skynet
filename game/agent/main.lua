local skynet = require "skynet"
local protobuf = require "protobuf"
local netpack = require "websocketnetpack"
local socket = require "socket"
local user_info = require "user_info"
local config_manager = require "config_manager"
local event_dispatcher = require "event_dispatcher"

local config = require "invoke"
local AGENT_OP = config.AGENT_OP
local CMD = config.CMD
-- gate will use client protocol for client's data
skynet.register_protocol( {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function (msg, sz)
        return protobuf.decode("C2GS", msg, sz)
    end,

    dispatch = function (_, _, msg, pbc_error)

        if pbc_error or not msg then
            skynet.error("pbc_error=>",pbc_error)
            return
        end

        local msg_name, data = next(msg)

        if msg_name == "heart_beat" then
            local buff, sz = netpack.pack(protobuf.encode("GS2C", {heart_beat_ret = {}}))
            socket.write(user_info.client_fd, buff, sz)
            return
        end  
        --客户端接到回应后才能发第二条消息
        if _G["SEASSION_PROCESS"] then
            return
        end
        _G["SEASSION_PROCESS"] = true
        while _G["SAVE_FLAG"] do
            skynet.yield()
        end
        local succ, proto, send_msg = xpcall(event_dispatcher.DispatchEvent, debug.traceback, event_dispatcher, msg_name, data)
        if succ and proto then
            local succ, err = pcall(user_info.ResponseClient, user_info, proto, send_msg)
            if not succ then
                skynet.error("response msg error:",err)
                user_info:ResponseClient("error_ret", {})
            end
        elseif proto then
            skynet.error("process msg error:",user_info.user_id)
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
    config_manager:Init()
    protobuf.register_file(skynet.getenv("protobuf"))
    event_dispatcher:Init(config_manager.msg_files_config)
end)
