local skynet = require "skynet"
local protobuf = require "protobuf"
local user_info = require "user_info"
local event_dispatcher = require "event_dispatcher"

--注册客户端协议
skynet.register_protocol( {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function (msg, sz)
        return protobuf.decode("C2GS", msg, sz)
    end,

    dispatch = function (_, _, msg, pbc_error)

        if pbc_error or not msg then
            skynet.error("PBC DECODE ERR:",pbc_error)
            return
        end

        local msg_name, content = next(msg)
        if msg_name == "heart_beat" then
            user_info:ResponseClient("heart_beat_ret",{})
            return
        end  

        --如果当前正在处理消息中,则直接return,等待客户端下一次发送消息过来
        if _G["SEASSION_PROCESS"] then
            return
        end

        _G["SEASSION_PROCESS"] = true
        local succ, ret, content = xpcall(event_dispatcher.DispatchEvent, debug.traceback, event_dispatcher, msg_name, content)
        if succ and proto then
            local msg_name = ret
            local succ, err = pcall(user_info.ResponseClient, user_info, msg_name, content)
            if not succ then
                skynet.error("RESPONSE ERROR:",err)
                user_info:ResponseClient("error_ret", {})
            end
        elseif ret then
            local err = ret
            skynet.error("PROCESS MESSAGE:",err)
            user_info:ResponseClient("error_ret", {})
        end
        _G["SEASSION_PROCESS"] = false
    end
})