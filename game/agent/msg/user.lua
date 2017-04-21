local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_info = require "user_info"
local user = {}
function user:Init()
    event_dispatcher:RegisterEvent("log_out",utils:handler(self,self.Logout)) 
    event_dispatcher:RegisterEvent("query_user_base_info",utils:handler(self,self.Query)) 
    event_dispatcher:RegisterEvent("create_leader",utils:handler(self,self.CreateLeader)) 
end

function user:Logout(recv_msg)
    local ret = {reason = "success"}
    local send_msg = { reason = "success" }
    user_info:Logout()
    return "log_out_ret",ret
end

function user:CreateLeader(recv_msg)
    user_info:LoadDefaultInfo()
    user_info:CreateLeader(recv_msg.name, recv_msg.channel)
    return "create_leader_ret", { result = "success" , name = recv_msg.name}
end

function user:Query(recv_msg)
    local ret = {}
    ret.leader_name = "DDDDEGDAEG"
    return "query_user_base_info_ret",ret
end



return user