local skynet = require "skynet"
local utils = require "utils"
local user_info = require "user_info"
local config_manager = require "config_manager"
local protobuf = require "protobuf"
local event_dispatcher = require "event_dispatcher"

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
--------------------------------------------------------------
--有新的好友申请过来
--------------------------------------------------------------
function AGENT_OP.NewInvitation(src_friend_info)
    --推送到客户端
end
--------------------------------------------------------------
--新增好友
--------------------------------------------------------------
function AGENT_OP.NewFriend(src_friend_info)
    --推送到客户端
end
--------------------------------------------------------------
--删除好友
--------------------------------------------------------------
function AGENT_OP.RemoveFriend(src_user_id)
    --推送到客户端
end


local CMD = {}
--------------------------------------------------------------
--玩家登录处理
--------------------------------------------------------------
function CMD.Start(gate,fd,ip,is_new_agent,user_id,server_id,platform,logintype,locale)
    --通知gate 将fd的消息转发到本服务
    skynet.call(gate, "lua", "forward", fd)
    local is_create_leader = false
    --如果是新的agent
    if is_new_agent then
        --加载默认数据
        user_info:LoadDefault()
        --加载数据库数据
        local has_data = user_info:LoadFromDb(user_id)
        if not has_data then
            is_create_leader = true
        end
    end

    user_info:Init(fd,ip,user_id,server_id,platform,logintype,locale)
    local time_zone = utils:getTimeZone()
    if not is_create_leader then
        local send_msg = {result = "success",server_time = skynet.time(),user_id = user_id,time_zone = time_zone}
        user_info:ResponseClient("login_ret",send_msg)
    else
        local send_msg = {result = "create_role",server_time = skynet.time(),user_id = user_id,time_zone = time_zone}
        user_info:ResponseClient("login_ret",send_msg)
    end
    --TODO login_log
end
--发送一个退出信息给客户端
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
    local succ, err = xpcall(user_info.Clear,debug.traceback,user_info)
    if not succ then
        skynet.error("ERROR CODE = 3001 errmsg = ",err)
    end
    _G["SEASSION_PROCESS"] = false
    collectgarbage "collect"
end


local command = {AGENT_OP = AGENT_OP,CMD = CMD}

function command.Init()
    config_manager:Init()
    protobuf.register_file(skynet.getenv("protobuf"))
    event_dispatcher:Init(config_manager.msg_files_config)
end

return command