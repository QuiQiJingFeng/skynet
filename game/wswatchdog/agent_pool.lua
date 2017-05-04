local skynet = require "skynet"
local cls = require "skynet.queue"
local queue = cls()
local AGENT_POOL_NUM = 1      --预留500个agent

local agent_pool = {}
--预留
function agent_pool:Init()
    self.reclaim_pool = {}

    for i = 1, AGENT_POOL_NUM do
        local agent = self:CreateAgent()
        table.insert(self.reclaim_pool,agent)
    end
end
--创建agent
function agent_pool:CreateAgent()
    local service_id = skynet.newservice("agent")
    local agent = {}
    function agent:Reset()
        self.service_id = -1
        self.fd = -1
        self.user_id = ""
        --下一次保存的时间点
        self.save_time = 0
        --失效时间点
        self.expire_time = 0
        --回收标记,当失效时间过去的时候回收标记被置为true,同时在下一次调度的时候放入回收池
        self.can_be_reclaim = false
        --是否加锁,当对agent操作的时候,避免正好被重用
        self.lock = false
    end
    agent:Reset()
    agent.service_id = service_id

    return agent
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
    agent:Reset()
    table.insert(self.reclaim_pool,agent)
end


return agent_pool