local skynet = require "skynet"
local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_info = require "user_info"
local config_manager = require "config_manager"

---------------------------------------------------------------
--登出
---------------------------------------------------------------
event_dispatcher:RegisterEvent("log_out",function(recv_msg)
    local ret = {reason = "success"}
    local send_msg = { reason = "success" }
    return "log_out_ret",ret
end)

---------------------------------------------------------------
--创建角色名
---------------------------------------------------------------
event_dispatcher:RegisterEvent("create_name",function(recv_msg)
    local ret = {result = "success"}
    local user_name = recv_msg.user_name
    --屏蔽emoji字符
    local is_emoji = utils:checkEmoji(user_name)
    if is_emoji then
        ret.result = "has_emoji"
        return "create_name_ret",ret
    end

    local role_id = recv_msg.role_id

    --检查名称是否已经存在
    local user_id = user_info._info.base_info.user_id
    local is_exist = skynet.call(".social","lua","CheckNewName",user_name,user_id)
    if is_exist then
        ret.result = "name_exist"
        return "create_name_ret",ret
    end
    user_center.base_info.user_name = user_name
    shield.call(".social", "lua", "NewUser", user_id, user_name, role_id)

    return "create_name_ret",ret
end)
