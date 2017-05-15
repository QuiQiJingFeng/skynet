local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_center = require "module.user_center"
local config_manager = require "config_manager"
local user = {}
function user:Init()
    event_dispatcher:RegisterEvent("log_out",utils:handler(self,self.Logout)) 
    event_dispatcher:RegisterEvent("create_name",utils:handler(self,self.CreateName)) 
end

function user:Logout(recv_msg)
    local ret = {reason = "success"}
    local send_msg = { reason = "success" }
    return "log_out_ret",ret
end
--创建角色名
function user:CreateName(recv_msg)
    local ret = {result = "success"}
    local user_name = recv_msg.user_name
    --屏蔽emoji字符
    local is_emoji = utils:checkEmoji(user_name)
    if is_emoji then
        ret.result = "has_emoji"
        return "create_name_ret",ret
    end
    --最大字符数量
    local max_num =  config_manager.constants_config["MAX_NUM_CHAR"]
    local num = #utils:strSplit(user_name)
    print("num,max_num",num,max_num)
    print(type(num),type(max_num))
    if num > max_num then
        ret.result = "max_num_char"
        return "create_name_ret",ret
    end

    user_center:SetName(user_name)
    return "create_name_ret",ret
end

return user