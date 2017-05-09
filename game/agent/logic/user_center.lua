local skynet = require "skynet"
local config_manager = require "config_manager"

local user_center = {}

function user_center:Init()
    
end

function user_center:SetLoginInfo(user_id,server_id,channel,locale)
    --记录最后一次登录的时间
    self.last_login_time = math.ceil(skynet.time())
    self.user_id = user_id
    self.server_id = server_id
    self.channel = channel
    self.locale = locale
end

function user_center:Save()
    
end

function user_center:Close()
    
end

return user_center