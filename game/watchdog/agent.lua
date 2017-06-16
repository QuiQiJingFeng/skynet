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
    self.service_id = -1
    self.fd = -1
    self.user_id = ""
    self.save_time = 0              --下一次保存的时间点
    self.expire_time = 0            --失效时间点
    self.can_be_reclaim = false     --回收标记,当失效时间点过去的时候回收标记被置为true
    self.lock = false               --是否加锁,当对agent操作的时候,避免正好被重用
end


return agent