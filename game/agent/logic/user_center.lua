local skynet = require "skynet"
local config_manager = require "config_manager"

local user_center = {}

function user_center:Init(db,user_info_key)
    self.last_login_time = math.ceil(skynet.time())
    
end

function user_center:Save(db,user_info_key)
    db:hmset(user_info_key,"last_login_time", self.last_login_time)
end

function user_center:Close()
    
end

return user_center