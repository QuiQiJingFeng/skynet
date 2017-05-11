local skynet = require "skynet"
local print = skynet.error
local utils = {} 

--将秒数转换成日期
function utils.convertToDate(seconds)
  return os.date("%Y/%m/%d %H:%M:%S",math.ceil(seconds));
end

--字符串操作相关
function utils.replaceStr(str,origin,target)
    return string.gsub(str, origin, target)
end

--字符串截取  闭区间
function utils.getSubString(str,startPos,endPos)
    return string.sub(str,startPos,endPos)  
end

--获取字符串的长度
function utils.getStrLength(str)
  return string.len(str)  -- 获取字符串的长度
end 

--字符串替换  将字符串中的空格去掉
function utils.trim(str)
    return string.gsub(str," ", "");
end

function utils.split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function utils.checkEmoji(str)
    local has_emoji = false
    for uchar in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        local len = string.len(uchar)
        if string.find(v, "[\226][\132-\173]") or string.find(v, "[\227][\128\138]") then
            has_emoji = true
            break
        elseif len >= 4 then
            has_emoji = true
            break            
        end
    end
    return has_emoji
end

--比较版本号
function utils.greaterVersion(version1,version2)
    local a,b,c = string.match(version1, "(%d+).(%d+).(%d+)") 
    local v1 = a* 1000 + b*100 + c
    a,b,c = string.match(version1, "(%d+).(%d+).(%d+)") 
    local v2 = a* 1000 + b*100 + c
    return version1 >= version2
end
--获取当前是周几  周日返回的是0,所以这里处理下让其返回7
function utils.getWDay(time)
    local num = tonumber(os.date("%w",time))
    num = (num == 0) and 7 or num
    return num
end


function utils.handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

--table相关
---------------------------
--查询指定元素在数组中的位置
---------------------------
function utils.indexOf(array,item)
    for key, var in pairs(array) do
        if (var == item) then
            return key;
        end
    end
    return -1;
end

---------------------------
--删除数组中指定的元素
---------------------------
function utils.remove(array,item)
    local index=utils:indexOf(array,item);
    if (index>=1) then
        table.remove(array,index);
        return true
    end
    return false
end

---------------------------
--获取指定key满足某数据的数组key
---------------------------
function utils.indexOfByKey(array, key, cond)
    for k, var in ipairs(array) do
        if (tostring(var[key]) == tostring(cond)) then
            return k;
        end
    end
    return -1;
end


---------------------------
--数组合并,返回新的数组
---------------------------
function utils.merge(array1, array2)
    local newList = {};
    if array1 ~= nil then
        for key, var in pairs(array1) do
            table.insert(newList,var)
        end
    end
    if array2 ~= nil then
        for key, var in pairs(array2) do
            table.insert(newList,var)
        end
    end
    return newList;
end

---------------------------
--给数组的每一项都加一个属性
---------------------------
function utils.tableAddAttr(tab, key, value)
    for _, var in pairs(tab) do
        var[key] = value;
    end
end
 
function utils.dump(value, desciption, nesting)
    local function dump_value_(v)
        if type(v) == "string" then
            v = "\"" .. v .. "\""
        end
        return tostring(v)
    end
    function string.trim(input)
        input = string.gsub(input, "^[ \t\n\r]+", "")
        return string.gsub(input, "[ \t\n\r]+$", "")
    end
    function string.split(input, delimiter)
        input = tostring(input)
        delimiter = tostring(delimiter)
        if (delimiter=='') then return false end
        local pos,arr = 0, {}
        -- for each divider found
        for st,sp in function() return string.find(input, delimiter, pos, true) end do
            table.insert(arr, string.sub(input, pos, st - 1))
            pos = sp + 1
        end
        table.insert(arr, string.sub(input, pos))
        return arr
    end

    if type(nesting) ~= "number" then nesting = 3 end

    local lookupTable = {}
    local result = {}

    local traceback = string.split(debug.traceback("", 2), "\n")
    print("dump from: " .. string.trim(traceback[3]))

    local function dump_(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        local spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(dump_value_(desciption)))
        end
        if type(value) ~= "table" then
            result[#result +1 ] = string.format("%s%s%s = %s", indent, dump_value_(desciption), spc, dump_value_(value))
        elseif lookupTable[tostring(value)] then
            result[#result +1 ] = string.format("%s%s%s = *REF*", indent, dump_value_(desciption), spc)
        else
            lookupTable[tostring(value)] = true
            if nest > nesting then
                result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, dump_value_(desciption))
            else
                result[#result +1 ] = string.format("%s%s = {", indent, dump_value_(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = dump_value_(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    dump_(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = string.format("%s}", indent)
            end
        end
    end
    dump_(value, desciption, "- ", 1)

    for i, line in ipairs(result) do
        print(line)
    end
end

local CONVERT = { [10] = "A", [11] = "B", [12] = "C", [13] = "D", [14] = "E", [15] = "F", [16] = "G",
[17] = "H", [18] = "I", [19] = "J", [20] = "K", [21] = "L", [22] = "M", [23] = "N", [24] = "O", [25] = "P",
[26] = "Q", [27] = "R", [28] = "S", [29] = "T",[30] = "U", [31] = "V",[32] = "W",[33] = "X", [34] = "Y", [35] = "Z" }
--转换成32进制
function utils.convertTo32(number)
    local unin_id = ""
    local multiple = 0
    while number > 0 do
        local dec = number%36
        number = math.floor(number/36)
        dec = CONVERT[dec] or dec
        unin_id = dec .. unin_id
        multiple = multiple + 1
    end
    return unin_id
end

return utils;
 