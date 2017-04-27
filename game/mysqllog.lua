local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local mysql = require "mysql"

local CMD = {}
---------------------------
--log_name 表名
--data 表的字段和值 例如：{user_id = "5YC1U",name = "\\鹊起"}
--quote 是否对字段进行转义
--比如name = "\\鹊起",存入数据库的是"\鹊起"
--当再从数据拿出来的时候，name 变成了"\鹊起",而我们需要的是"\\鹊起",所以这里对有可能的转义字符进行转义
--一般来说 用户输入的内容都是需要进行转义的
---------------------------
function ConvertSql(log_name,data,quote)
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
            if value ~= "now()" then
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

function CMD.InsertLog(log_name,data,is_quote)
     local sql = ConvertSql(log_name,data,is_quote)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        f(...)
    end)

    

    skynet.register(".mysqllog")
end)