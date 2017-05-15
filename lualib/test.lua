local utils = require "utils"
--创建角色名
function CreateName(recv_msg)
    local ret = {result = "success"}
    local user_name = recv_msg.user_name
    --屏蔽emoji字符
    local is_emoji = utils:checkEmoji(user_name)
    if is_emoji then
        ret.result = "has_emoji"
        return ret
    end
    --最大字符数量
    local max_num =  16
    local num = #utils:strSplit(user_name)
    print("num,max_num",num,max_num)
    print(type(num),type(max_num))
    if num > max_num then
        ret.result = "max_num_char"
        return ret
    end

    return ret
end

-- utils:dump(CreateName({user_name="FFFFF㉿"}))

local tb = utils:utf8to32("AAAA中熬😀😂")
local str = table.concat(tb)
for i,v in ipairs(tb) do
    print(i,string.format("%#x",v))
end

for i,v in ipairs(tb) do
    local emoji = utils:isEmoji(v)
    if emoji then
        print("含有emoji字符=>",string.format("%#x",v))
    end
end
