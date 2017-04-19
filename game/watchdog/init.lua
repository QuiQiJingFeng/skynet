local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local netpack = require "netpack"
local protobuf = require "protobuf"
local mysql = require "mysql"
local redis = require "redis"
local socket = require "socket"
local sharedata = require "sharedata"
local agent_manager = require "agent_manager"
local constant
local SOCKET_STATE
local CMD = {}
local SOCKET = {}
local gate

local agents = {}
local userid_to_agent = {}
local socket_to_agent = {}

function SOCKET.open(fd, ipaddr)
    local ip = string.match(ipaddr, "([%d.]+):")
    --记录已经连接的fd->states
    agents[fd] = {fd = fd, ip = ip}
    skynet.call(gate, "lua", "accept", fd)
end

local function close_agent(fd)
    local a = agents[fd]
    agents[fd] = nil
    if a then
        skynet.call(gate, "lua", "kick", fd)
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
    print("socket close",fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
end

local function onReceiveData(fd,msg)
    local ip = agents[fd].ip
    local succ, msg_data, pbc_error = pcall(protobuf.decode, "C2GS", msg)
    if not succ or not msg_data then
        skynet.error("pbc decode error==>", pbc_error)
        return false
    end

    if not msg_data["login"] then
        skynet.error("error: must have login proto")
        return false
    end

    local success,user_id = skynet.call(".logind","lua","Login",msg_data.login)
    if not success then
        local send_msg = { session = 0, login_ret = { result = "auth_failure" ,client_ip = ip} }
        local buff, sz = netpack.pack(pbc.encode("GS2C", send_msg))
        socket.write(fd, buff, sz)
        return true
    end
    
    assert(user_id)

    local agent = agent_manager:create_agent()
    
    local start_ret = skynet.call(agent.service_id, "lua", "Start",gate,fd,ip,user_id,msg_data.login)
    if start_ret ~= "success" then
        skynet.error("=====start error=====",start_ret)
        return false
    end
    agents[fd].state = SOCKET_STATE.working

    agent.user_id = user_id
    --绑定新的fd和ip
    agent.fd = fd
    
    --记录user_id->agent fd->agent映射
    userid_to_agent[user_id] = agent
    socket_to_agent[fd] = agent

    return true
end

function SOCKET.data(fd, msg)
    if not onReceiveData(fd, msg) then
        skynet.call(gate, "lua", "kick", fd)
    end
end

function CMD.start(conf)
    --开启gate网关服务,监控外部网络连接
    skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
    close_agent(fd)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    constant = sharedata.query('constant')
    SOCKET_STATE = constant.SOCKET_STATE

    protobuf.register_file(skynet.getenv("protobuf"))
    --protobuf
    --[[ protobuf 操作
        print("=====================================")
        protobuf.register_file("proto/msg.pb")
        local t = protobuf.encode("C2GS", {session=10})
        local msg = protobuf.decode("C2GS", t)
        print("=============")
        print("session = ",msg.session)
        print("======================================")
    --]]
    --mysql
    --[[mysql 操作
        local function on_connect(db)
            db:query("set charset utf8");
        end
        local db=mysql.connect({
            host="127.0.0.1",
            port=3306,
            database="aam_1",
            user="root",
            max_packet_size = 1024 * 1024,
            on_connect = on_connect
        })
        --创建表
        local sql = "CREATE TABLE IF NOT EXISTS `XXXXX` (  `id` INT NOT NULL AUTO_INCREMENT,  `user_id` VARCHAR(16) DEFAULT '',  `mercenary_id` VARCHAR(16) DEFAULT '',  `template_id` VARCHAR(16) DEFAULT '', `artifact_level` INT UNSIGNED DEFAULT 0,  cur_time DATETIME,  PRIMARY KEY (`id`),  KEY `user_mercenary` (`user_id`,`mercenary_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
        local ret = db:query(sql)
        if ret.badresult then
            skynet.error("err=>",ret.err)
        end
        --插入表
        local sql2 = "INSERT INTO `XXXXX` (id,user_id,mercenary_id,template_id,artifact_level,cur_time) VALUES(%d,'%s','%s','%s',%d,now())"
        sql2 = string.format(sql2,123,"\\\\5YC12","3453","19998833",23)
        ret = db:query(sql2)
        if ret.badresult then
            skynet.error("err=>",ret.err)
        end
        --查询表
        local sql3 = "SELECT * FROM `XXXXX`;"
        ret = db:query(sql3)

        if not ret.badresult then
            for k,v in pairs(ret) do
                print(k,v)
            end
        end
    ]]
    --redis
    --[[redis 操作
        local conf = {
            host = "127.0.0.1",
            port = 6379,
            db = 0
        }
        local db = redis.connect(conf)
        db:set("key1","value1")
        local value = db:get("key1")
        print("value = ",value)
    --]]

    gate = skynet.newservice("gate")

    skynet.register(".watchdog")
end)
