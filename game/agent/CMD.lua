local user_info = require "user_info"

local CMD = {}
--------------------------------------------------------------
--玩家登录处理
--------------------------------------------------------------
function CMD.Start(gate,fd,ip,is_new_agent,user_id,data)
    --通知gate 将fd的消息转发到本服务
    skynet.call(gate, "lua", "forward", fd)

    user_info:Init(user_id,data.server_id,data.channel,data.locale,fd,ip)
    if is_new_agent then
        user_info:LoadFromDb(user_id)
    end

    local time_zone = utils:getTimeZone()
    local send_msg = {  
                        result = "success",
                        server_time = skynet.time(),
                        user_id = user_id,
                        time_zone = time_zone
                     }
    user_info:ResponseClient("login_ret",send_msg)

    local log_msg = {  
                        user_id = user_id,
                        server_id = data.server_id,
                        account = data.account,
                        ip = ip,
                        platform = data.platform,
                        channel = data.channel,
                        net_mode = data.net_mode,
                        device_id = data.device_id,
                        device_type = data.device_type,
                        time = "NOW()"
                    }
    skynet.send(".mysqllog","lua","InsertLog","login_log",log_msg)
end
--发送一个退出信息给客户端
function CMD.Kick(reason)
    user_info:ResponseClient("logout_ret", { reason = reason })
end

--重用的时候
function CMD.Logout()
    user_info:SetClientFd(-1)
end
 
--该agent被回收
function CMD.Close()
    local succ, err = xpcall(user_info.Clear,debug.traceback,user_info)
    if not succ then
        skynet.error("ERROR CODE = 3001 errmsg = ",err)
    end
    _G["SEASSION_PROCESS"] = false
    collectgarbage "collect"
end

return CMD