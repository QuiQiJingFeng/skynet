local skynet = require "skynet"
local config_manager = require "config_manager"

local user_center = {}

function user_center:Init(db,user_info_key)
    self.last_login_time = math.ceil(skynet.time())
    self.user_name = db:hget(user_info_key,"user_name")

    --所有的标识位都写在这里,方便查看
    self.user_name_flag = nil
    self.login_time_flag = true
end

function user_center:Save(db,user_info_key)
    --判断当前存储次数,可以将仅仅需要在登录的时候存储一次的
    if self.login_time_flag then
        db:hmset(user_info_key,"last_login_time",self.last_login_time)
        self.login_time_flag = nil
    end
    --设立标志位，这样可以仅仅在需要存储的时候存储
    if self.user_name_flag then
        db:hmset(user_info_key,"user_name", self.user_name)
        self.user_name_flag = nil
    end

end

function user_center:Close()
    self.last_login_time = nil
    self.user_name = nil
    self.user_name_flag = nil
end
--设置玩家名称
function user_center:SetName(user_name)
    self.user_name = user_name
    self.user_name_flag = true
end

return user_center