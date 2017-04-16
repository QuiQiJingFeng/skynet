local skynet = require "skynet"
local netpack = require "netpack"
local protobuf = require "protobuf"
local mysql = require "mysql"
local redis = require "redis"
local CMD = {}
local SOCKET = {}
local gate
local agent = {}




function SOCKET.open(fd, ipaddr)
    skynet.error("New client from : " .. ipaddr)
    -- agent[fd] = skynet.newservice("agent")
    -- skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
end

local function close_agent(fd)
    local a = agent[fd]
    agent[fd] = nil
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

function SOCKET.data(fd, msg)
    print("SOCKET.data =>",msg)
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
    --protobuf
    --[[ protobuf 操作
        print("=====================================")
        protobuf.register_file("proto/msg.pb")
        local t = protobuf.encode("C2GS", {session=10})
        local msg = protobuf.decode2("C2GS", t)
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
end)
