local skynet = require "skynet"

local agent = {}

function agent:New()
    local inst = {}
    setmetatable(inst,{__index = self})
    inst:Init()
    return inst
end

function agent:Init()
    self:LoadDefault()
    self.service_id = skynet.newservice("agent") 
end

function agent:LoadDefault()
    self.fd = -1
    self.user_id = ""
    self.expire_time = 0            --失效时间点
    self.lock = false               --是否加锁,当对agent操作的时候,避免正好被重用
end


return agent