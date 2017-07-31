local skynet = require "skynet"
local mysql = require "mysql"
local utils = require "utils"
local gamedb = {}
local cur_db_index = 1
local command = {}

local function UpdateDbIndex()
    cur_db_index = cur_db_index + 1
    if cur_db_index > #gamedb then
        cur_db_index = 1
    end
end

local function DoQuery(sql)
    UpdateDbIndex()
    local ret = gamedb[cur_db_index]:query(sql) or {}
    if ret.badresult then
        skynet.error("SQL ERROR:",ret.err)
        skynet.error("SQL :",sql)
    end

    return ret
end

---------------------------
--将table转化成插入sql语句
---------------------------
local function ConvertInsertSql(log_name,data,quote)
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

function command.Init()
    local function on_connect(db)
        db:query("set charset utf8");
    end

    for i=1,1 do
        gamedb[i] = mysql.connect({
                host="127.0.0.1",
                port=3306,
                user="root",
                database = "game",
                max_packet_size = 1024 * 1024,
                on_connect = on_connect
            })
    end

    DoQuery("create database if not exists `game`;")
    DoQuery("use `game`;")
    --register_log
    DoQuery("CREATE TABLE IF NOT EXISTS register_log ( id INT NOT NULL AUTO_INCREMENT,server_id INT NOT NULL,user_id   VARCHAR(16) NOT NULL,account   VARCHAR(32) NOT NULL, ip  VARCHAR(16) NOT NULL,platform  VARCHAR(16) DEFAULT '', channel   VARCHAR(16) DEFAULT '',net_mode   VARCHAR(16) DEFAULT '',device_id VARCHAR(32) DEFAULT '',device_type VARCHAR(32) DEFAULT '',time DATETIME, PRIMARY KEY (id),key(user_id,server_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")
    --login_log
    DoQuery("CREATE TABLE IF NOT EXISTS `login_log`(id INT NOT NULL AUTO_INCREMENT,server_id INT NOT NULL,user_id   VARCHAR(16) NOT NULL,account   VARCHAR(32) NOT NULL, ip  VARCHAR(16) NOT NULL, platform  VARCHAR(16) DEFAULT '', channel   VARCHAR(16) DEFAULT '', net_mode   VARCHAR(16) DEFAULT '',device_id VARCHAR(32) DEFAULT '',device_type VARCHAR(32) DEFAULT '',time DATETIME,PRIMARY KEY (id),KEY(user_id,server_id))ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")
end

function command.InsertLog(log_name,data,is_quote)
     local sql = ConvertInsertSql(log_name,data,is_quote)
     return DoQuery(sql)
end

return command