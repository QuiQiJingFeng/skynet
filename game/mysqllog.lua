local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local mysql = require "mysql"
local utils = require "utils"
local gamedb 
local CMD = {}
local manager = {}

local MINUTE_NUM = 100000
--------------------
--初始化  创建所有需要的数据库以及表
--------------------
function manager:Init()
    local tables = {}
    local databases = [[
                            create database if not exists `game`;
                            create database if not exists `history_log`;
                      ]] 

    table.insert(tables,databases)

    local selectdb = "use game;"
    table.insert(tables,selectdb)    

    local login_log = [[
                            CREATE TABLE IF NOT EXISTS `login_log`(
                                    user_id   VARCHAR(16) NOT NULL,
                                    account   VARCHAR(32) NOT NULL,  
                                    login_ip  VARCHAR(16) NOT NULL,  
                                    platform  VARCHAR(16) NOT NULL, 
                                    channel   VARCHAR(16) NOT NULL,  
                                    netmode   VARCHAR(16) DEFAULT '', 
                                    device_id VARCHAR(32) DEFAULT '',
                                    login_time DATETIME
                            )ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                      ]]
    table.insert(tables,login_log)

    local resource_log = [[
                        CREATE TABLE IF NOT EXISTS `resource_log`(
                                user_id         VARCHAR(16) NOT NULL,
                                resource_type   VARCHAR(16) NOT NULL,  
                                count           double DEFAULT 0,
                                time            DATETIME
                        )ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                  ]]
    table.insert(tables,resource_log)

    for table_name,sql in pairs(tables) do
        manager:DoQuery(sql)
    end
end
---------------------------
--将table转化成插入sql语句
---------------------------
function manager:ConvertInsertSql(log_name,data,quote)
    local query = string.format("insert into `%s` ",log_name)
    local fileds = {}
    local values = {}
    for field,value in pairs(data) do
        if type(field) ~= "string" then
            return "filed must be string"
        end
         table.insert(fileds,field)

         local temp_value = string.gsub(value," ", ""); 
         if type(value) == 'string' then
            if value ~= "now()" and value ~= "NOW()" then
                if quote then
                    temp_value = mysql.quote_sql_str(temp_value)
                else
                    temp_value = string.format("'%s'",temp_value)                    
                end
            end
         end
         table.insert(values,temp_value)
    end

    local query = query .."("..table.concat(fileds,",")..") values("..table.concat(values,",")..");"
    return query
end
---------------------------
--分表操作
---------------------------
function manager:MinuteTable(origin_name,new_name)
    new_name = "history_log."..new_name
    local createnewtable = string.format("create table if not exists %s like %s;",new_name,origin_name)
    local locktable = "LOCK TABLES "..origin_name.." WRITE,"..new_name.." WRITE;"
    local renametable = string.format("INSERT INTO %s SELECT * FROM %s;",new_name,origin_name)
    local deltable = string.format("truncate table %s;",origin_name)
    local unlocktable = "UNLOCK TABLES;"
    manager:DoQuery(createnewtable..locktable..renametable..deltable..unlocktable)
end

function manager:DoQuery(sql)
    local ret = gamedb:query(sql) or {}
    if ret.badresult then
        skynet.error(ret.err,"===>\n",sql)
    end

    return ret
end
--------------------
--插入
--log_name 要插入的表名
--data 要插入的数据
--是否需需要处理转义字符处理

--一般来说 用户输入的内容都是需要进行转义的
--log_name 表名
--data 表的字段和值 例如：{user_id = "5YC1U",name = "\\鹊起"}
--quote 是否对字段进行转义
--比如name = "\\鹊起",存入数据库的是"\鹊起"
--当再从数据拿出来的时候，name 变成了"\鹊起",而我们需要的是"\\鹊起",所以这里对有可能的转义字符进行转义
--------------------
function CMD.InsertLog(log_name,data,is_quote)
     local sql = manager:ConvertInsertSql(log_name,data,is_quote)
     local ret = manager:DoQuery(sql)
     --大于100W进行分表  如果没有自增的ID的话 insert_id始终为0,所以如果需要自动分表,则必须有自增的ID
     if ret.insert_id ~= 0 and ret.insert_id % MINUTE_NUM == 0 then 
        local new_name = log_name..os.date("%Y_%m_%d_H_M",math.ceil(skynet.time()));
        --按日期分表
        manager:MinuteTable(log_name,new_name)
     end
end

function CMD.TEST()
    print("test====================")

     local function CreateUserId(max_id,server_id)
        local user_id = tonumber(string.format("%d%07d", server_id, max_id))
        return user_id
    end

    local res = {"GOLD","BLOOD","RUNE","MAGIC","EXP","VIP","MAGIC_CORE"}
    local data = {}
    for i=1,10000000 do
        data.user_id = CreateUserId(i,1)
        local idx = math.ceil(math.random(1,7))
        data.resource_type = res[idx]
        local num = math.ceil(math.random(0,100000))
        data.count = num
        data.time = "NOW()"

        CMD.InsertLog("resource_log",data)
    end
    print("test1====================end")
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        f(...)
    end)
     local function on_connect(db)
        db:query("set charset utf8");
    end
    gamedb = mysql.connect({
        host="127.0.0.1",
        port=3306,
        user="root",
        password = "fhqydidxil1zql",
        max_packet_size = 1024 * 1024,
        on_connect = on_connect
        })

    manager:Init()
end)