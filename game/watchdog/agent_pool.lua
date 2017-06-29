local skynet = require "skynet"
local agent = require "agent"
--预留500个agent
local AGENT_POOL_NUM = skynet.getenv("agent_pool_num") or 500

local agent_pool = {}
------------------------------------------------------
--初始化agent重用池 预创建n个agent
------------------------------------------------------
function agent_pool:Init()
    self.reclaim_pool = {}
    for i = 1, AGENT_POOL_NUM do
        self:CreateAgent()
    end
end

function agent_pool:CreateAgent()
    local new = agent:New()
    table.insert(self.reclaim_pool,new)
end

--取出一个可用的agent
function agent_pool:Dequeue()
    if #self.reclaim_pool > 0 then
        return table.remove(self.reclaim_pool,1)
    else
        return self:CreateAgent()
    end
end

--将agent放入重用池
function agent_pool:Push(agent)
    agent:LoadDefault()
    table.insert(self.reclaim_pool,agent)
end


return agent_pool