local skynet = require "skynet"
local protobuf = require "protobuf"
local agent_pool = require "agent_pool"
local netpack = require "websocketnetpack"
local socket = require "socket"
local AGENT_POLL_TIME = 60  --每60s调度一次
local AGENT_EXPIRE_TIME = 30*60 --当玩家退出后,保留agent 30 分钟
local AGENT_SAVE_TIME = 10*60   --玩家数据 每10分钟保存一次
local gateserver

local agent_manager = {}
function agent_manager:Init(gate)
    --网关服务地址
    gateserver = gate
    --user_id=>agent的映射
    self.userid_to_agent = {}
    --socket=>agent的映射
    self.socket_to_agent = {}
    --重用池
    agent_pool:Init()
    self.online_num = 0
end

---------------------------------------------------------------------------------------
    --FYD:
    --1、socket线程有登录消息过来的时候传到watchdog服务的消息队列
    --2、一个空闲的工作线程A来处理watchdog的消息队列
    --3、当在这里进行call调用的时候，当前协程挂起的时候(本次消息阻塞),工作线程A会继续处理下一个消息
    --4、call传递消息到logind服务的消息队列，空闲的工作线程B开始处理logind的消息队列
    --5、当logind服务返回时，添加到watchdog的消息队列，协程等待被唤醒
---------------------------------------------------------------------------------------
--处理接收到的数据
function agent_manager:ProcessData(msg)
    --数据的解析
    local succ, msg_data, pbc_error = pcall(protobuf.decode, "C2GS", msg)
    if not succ then
        skynet.error("decode error ==> agent_manager:ProcessData")
        return false
    elseif not msg_data then
        skynet.error("msg_data=>",pbc_error)
        return false
    end

    if not msg_data["login"] and not msg_data["reconnect"] then
        skynet.error("msg_data error")
        return false
    end

    return msg_data
end 

function agent_manager:SendToClient(fd,send_msg)
    local buff, sz = netpack.pack(protobuf.encode("GS2C", send_msg))
    socket.write(fd, buff, sz)
end

function agent_manager:ProcessLogin(fd,data,ip)
    local result,user_id = skynet.call(".logind","lua","Login",data,ip)
    if result ~= "success" then
        send_msg = {login_ret = { result = result} }
        self:SendToClient(fd,send_msg)
        return true
    end 
    assert(user_id)
    --检测重复登录
    local agent = self.userid_to_agent[user_id]
    if agent then
        if agent.fd >= 0 then 
            self.socket_to_agent[agent.fd] = nil
            skynet.call(agent.service_id, "lua", "Kick", "repeated_login")
            skynet.call(gateserver, "lua", "kick", agent.fd)
        end
    else
        agent = agent_pool:Dequeue()
    end
    skynet.call(agent.service_id, "lua", "Start",gateserver,fd,ip,user_id,data)
    agent.user_id = user_id
    agent.fd = fd

    self.userid_to_agent[user_id] = agent
    self.socket_to_agent[fd] = agent

    return true
end
--TODO
function agent_manager:ProcessReconnect(data)
    --断线重连
end

--客户端消息处理
function agent_manager:OnReceiveData(fd,msg,ip)
    
    local recv_data = self:ProcessData(msg)
    if not recv_data then
        return false
    end

    local send_msg,user_id
    if recv_data.login then
       return self:ProcessLogin(fd,recv_data.login,ip)
    elseif recv_data.reconnect then
        return self:ProcessReconnect(recv_data.reconnect)
    end

    

    return true
end

--设置失效时间
function agent_manager:SetExpireTime(fd)
    --断开socket跟agent的映射
    local agent = self.socket_to_agent[fd]
    self.socket_to_agent[fd] = nil

    if agent then
        agent.fd = -1
        agent.expire_time = skynet.time() + AGENT_EXPIRE_TIME
        skynet.send(agent.service_id, "lua", "Logout")
    end
end

--将失效的agent加入重用池中
function agent_manager:ReclaimAgent(agent)
    if self.userid_to_agent[agent.user_id] then
        self.userid_to_agent[agent.user_id] = nil
    end
    local close_ret = skynet.call(agent.service_id, "lua", "Close")
    if close_ret then
        skynet.error("agent close success")
    end
    agent_pool:Push(agent)
end

--循环检测失效的agent 以及定时agent的数据
local function SaveTimer()
    skynet.timeout(AGENT_POLL_TIME * 100, SaveTimer)
    if not agent_manager.userid_to_agent then
        return 
    end

    local t_now = skynet.time()
    local tmp_agent_map = {}
    --当前在线人数
    local online_num = 0

    for user_id, agent in pairs(agent_manager.userid_to_agent) do
        if t_now >= agent.save_time then
            if not agent.can_be_reclaim then
                agent.save_time = t_now + AGENT_SAVE_TIME
                --存储
                skynet.send(agent.service_id, "lua", "Save")
                --标记可重用
                if agent.expire_time > 0 then
                    agent.can_be_reclaim = true
                end
            elseif t_now >= agent.expire_time then
                tmp_agent_map[user_id] = agent
            end
        end
        --当前有效连接数量
        if agent.fd >= 0 then
            online_num = online_num + 1
        end
    end
    --对标记过的佣兵加入重用池
    for user_id, agent in pairs(tmp_agent_map) do
        --当agent正在进行某些操作而加锁的时候,不要将其放入回收池
        if not agent.lock then
            agent_manager:ReclaimAgent(agent)
        end
    end
    agent_manager.online_num = online_num
    --TODO:添加online记录
end

do
    skynet.timeout(AGENT_POLL_TIME * 100, SaveTimer)
end

return agent_manager