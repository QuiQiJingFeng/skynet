local skynet = require "skynet"
local utils = require "utils"
local user_info = require "user_info"

local AGENT_OP = {}

setmetatable(AGENT_OP, {
    __call = function(t, func_name, ...)
        while _G["SAVE_FLAG"] or _G["SEASSION_PROCESS"] do
            skynet.yield()
        end
        _G["SEASSION_PROCESS"] = true
        local func = AGENT_OP[func_name]
        local succ, ret = pcall(func,...)
        _G["SEASSION_PROCESS"] = false
        --执行错误在此结束协程, 阻止ret返回
        if not succ then
            assert(false)
        end

        return ret
    end
})

--------------------CUSTOM-------------
function AGENT_OP.DebugProto(msg_name, data)
    -- body
    
    local table_data = load("return " .. data)
    local recv_msg = table_data()

    print("-------receive client msg-------",msg_name)
    utils:dump(recv_msg,"-------",10)
    print("\n\n")

    local succ, proto, send_msg = xpcall(event_dispatcher.DispatchEvent, debug.traceback, event_dispatcher, msg_name, recv_msg)
    print("-------response client msg-------",proto)
    utils:dump(send_msg,"---------",10)

    return "OK"
end



local CMD = {}

--玩家第一次登录
function CMD.Start(gate,fd,ip,user_id,data)
    --请求socket=>fd的消息转发到本服务
    skynet.call(gate, "lua", "forward", fd)
    print("FYD=",user_id)
    user_info:Init(user_id,data.server_id,data.channel,data.locale,fd,ip)

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
    if _G["SAVE_FLAG"] then
        return true
    end
    while _G["SEASSION_PROCESS"] do
        skynet.yield()
    end
    _G["SAVE_FLAG"] = true
    local succ, ret = xpcall(user_info.Save, debug.traceback, user_info)
    if not succ then
        skynet.error(ret)
    elseif ret == false then
        succ = false
    end
    _G["SAVE_FLAG"] = false
    return succ
end

function CMD.AsynSave()
    CMD.Save()
end

--该agent被回收
function CMD.Close()
    user_info:Close()
    _G["SEASSION_PROCESS"] = false
    collectgarbage "collect"

    return true
end

return AGENT_OP,CMD