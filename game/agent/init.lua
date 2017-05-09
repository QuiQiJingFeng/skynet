local skynet = require "skynet"
local protobuf = require "protobuf"
local netpack = require "websocketnetpack"
local socket = require "socket"
local cls = require "skynet.queue"
local sharedata = require "sharedata"
local user_info = require "user_info"

local queue = cls()

local config_manager

local event_dispatcher

local save_flag = false
local session_processing = false


local CMD = {}
local AGENT_OP = {}

local TIME_ZONE = tonumber(skynet.getenv("time_zone"))

setmetatable(AGENT_OP, {
    __call = function(t, func_name, ...)
        while save_flag or session_processing do
            skynet.yield()
        end
        session_processing = true
        local func = AGENT_OP[func_name]
        local succ, ret = pcall(func,...)
        session_processing = false
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
        if session_processing then
            return
        end
        session_processing = true
        while save_flag do
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
        session_processing = false
    end
})

--玩家第一次登录
function CMD.Start(gate,fd,ip,user_id,data)
    --请求socket=>fd的消息转发到本服务
    skynet.call(gate, "lua", "forward", fd)
    
    --初始化user的数据
    user_info:Init(user_id,data,fd, ip)

    local send_msg = {result = "success",server_time = skynet.time(),user_id = user_id,time_zone = TIME_ZONE}
    user_info:ResponseClient("login_ret",send_msg)

    local log_msg = {  
                        user_id = user_id,server_id = data.server_id,
                        account = data.account,ip = ip,
                        platform = data.platform,channel = data.channel,
                        net_mode = data.net_mode,device_id = data.device_id,
                        device_type = data.device_type,time = "NOW()"
                    }
    --登录日志
    skynet.send(".mysqllog","lua","InsertLog","login_log",log_msg)

    return true
end

function CMD.Kick(reason)
    user_info:ResponseClient("logout_ret", { reason = reason })
    return true
end
--登出
function CMD.Logout()
    user_info:Logout()
end
--保存数据
function CMD.Save()
    if save_flag then
        return true
    end
    while session_processing do
        skynet.yield()
    end
    save_flag = true
    local succ, ret = xpcall(user_info.Save, debug.traceback, user_info)
    if not succ then
        skynet.error(ret)
    elseif ret == false then
        succ = false
    end
    save_flag = false
    return succ
end

function CMD.AsynSave()
    CMD.Save()
end

--该agent被回收
function CMD.Close()
    user_info:Close()
    session_processing = false
    collectgarbage "collect"

    return true
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

    

    config_manager = require "config_manager"
    config_manager:Init()

    event_dispatcher = require "event_dispatcher"
    event_dispatcher:Init(config_manager.msg_files_config)

end)
