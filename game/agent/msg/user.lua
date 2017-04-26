local event_dispatcher = require "event_dispatcher"
local utils = require "utils"
local user_info = require "user_info"
local user = {}
function user:Init()
    event_dispatcher:RegisterEvent("log_out",utils:handler(self,self.Logout)) 
end

function user:Logout(recv_msg)
    local ret = {reason = "success"}
    local send_msg = { reason = "success" }
    return "log_out_ret",ret
end

return user