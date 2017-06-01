local utils = {} 

--字符串操作相关
function utils:replaceStr(str,origin,target)
    return string.gsub(str, origin, target)
end

--字符串截取  闭区间
function utils:getSubString(str,startPos,endPos)
    return string.sub(str,startPos,endPos)  
end

--获取字符串的长度
function utils:getStrLength(str)
  return string.len(str)  -- 获取字符串的长度
end 

--字符串替换  将字符串中的空格去掉
function utils:trim(str)
    return string.gsub(str," ", "");
end

function utils:split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

---------------------------
--返回当前时区
---------------------------
function utils:getTimeZone()
    return tonumber(os.date("%z", 0))/100
end
---------------------------
--将格林威治时间转换成日期(本地时区转换)
---------------------------
function utils:convertToDate(time)
  return os.date("%Y/%m/%d %H:%M:%S",time);
end
---------------------------
--将格林威治时间转换成日期(指定时区转换)
---------------------------
function utils:convertToDate(time,time_zone)
  return os.date("!%Y/%m/%d %H:%M:%S",time + time_zone * 3600);
end
---------------------------
--获取当前是周几  周日返回的是0,所以这里处理下让其返回7(本地时区转换)
---------------------------
function utils:getWDay(time)
    local num = tonumber(os.date("%w",time))
    num = (num == 0) and 7 or num
    return num
end
---------------------------
--获取当前是周几  周日返回的是0,所以这里处理下让其返回7(指定时区转换)
---------------------------
function utils:getWDay(time,time_zone)
    local num = tonumber(os.date("!%w",time + time_zone * 3600))
    num = (num == 0) and 7 or num
    return num
end

---------------------------
--判断utf8字符的个数
---------------------------
function utils:utf8Length(s)
    return utf8.len(s)
end
---------------------------
--将UTF8字符串分割成字符数组
---------------------------
function utils:utf8Chars(utf8str)
    local chars = {}
    for p,c in utf8.codes(str) do
        table.insert(chars,c)
    end
    return chars
end
---------------------------
--判断是否为CJK(无法区分中、日、韩),但可以剔除emoji
--CJK 是中文（Chinese）、日文（Japanese）、韩文（Korean）三国文字的缩写。
---------------------------
function utils:checkChinese(str)
    local uchars = self:utf8Chars(str)
    for _,uchar in ipairs(uchars) do
        --判断CJK字符和中文标点
        if uchar >= 0x4E00 and uchar <= 0x9FCC then     
        elseif uchar >= 0xFF00 and uchar <= 0xFFEF then
        elseif uchar >= 0x2E80 and uchar <= 0x2EFF then
        elseif uchar >= 0x3000 and uchar <= 0x303F then
        elseif uchar >= 0x31C0 and uchar <= 0x31EF then
        elseif uchar >= 0x2F00 and uchar <= 0x2FDF then
        elseif uchar >= 0x2FF0 and uchar <= 0x2FFF then
        elseif uchar >= 0x3100 and uchar <= 0x312F then
        elseif uchar >= 0x31A0 and uchar <= 0x31BF then
        elseif uchar >= 0x3040 and uchar <= 0x309F then
        elseif uchar >= 0x30A0 and uchar <= 0x30FF then
        elseif uchar >= 0x31F0 and uchar <= 0x31FF then
        elseif uchar >= 0xAC00 and uchar <= 0xD7AF then
        elseif uchar >= 0x1100 and uchar <= 0x11FF then
        elseif uchar >= 0x3130 and uchar <= 0x318F then
        elseif uchar >= 0x4DC0 and uchar <= 0x4DFF then
        elseif uchar >= 0xA000 and uchar <= 0xA48F then
        elseif uchar >= 0x2800 and uchar <= 0x28FF then
        elseif uchar >= 0x3200 and uchar <= 0x32FF then
        elseif uchar >= 0x3300 and uchar <= 0x33FF then
        elseif uchar >= 0x2700 and uchar <= 0x27BF then
        elseif uchar >= 0x2600 and uchar <= 0x26FF then
        elseif uchar >= 0xFE10 and uchar <= 0xFE1F then
        elseif uchar >= 0xFE30 and uchar <= 0xFE4F then
        elseif uchar >= 0x1D300 and uchar <= 0x1D35F then
        else
            return false
        end
    end
    return true
end

--检查某个字符是否是emoji
function utils:isEmoji(unicode)
    --16进制转10进制
    if unicode >= 0x1F601 and unicode <= 0x1F64F then
    elseif unicode >= 0x2702 and unicode <= 0x27B0 then
    elseif unicode >= 0x1F680 and unicode <= 0x1F6C0 then
    elseif unicode >= 0x1F170 and unicode <= 0x1F251 then
    elseif unicode >= 0x1F600 and unicode <= 0x1F636 then
    elseif unicode >= 0x1F681 and unicode <= 0x1F6C5 then
    elseif unicode >= 0x1F30D and unicode <= 0x1F567 then
    else
        return false
    end
    return true
end

--检查字符串中是否包含emoji
function utils:checkEmoji(str)
    for uchar in self:utf8Chars() do
        if self:isEmoji(uchar) then
            return true
        end
    end
    return false
end

--比较版本号
function utils:greaterVersion(version1,version2)
    local a,b,c = string.match(version1, "(%d+).(%d+).(%d+)") 
    local v1 = a* 1000 + b*100 + c
    a,b,c = string.match(version1, "(%d+).(%d+).(%d+)") 
    local v2 = a* 1000 + b*100 + c
    return version1 >= version2
end

function utils:handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

---------------------------
--通过一个字段对数组排序，可以指定是否升序。默认为升
--比如要通过id对数组进行排序  {{id=3},{id=2}}
---------------------------
function utils:sortByField(tab,field,isAsc)
    if(isAsc==nil or isAsc==true) then
        table.sort(tab,function(v1,v2)
            return v2[field]>v1[field];
        end)
    else
        table.sort(tab,function(v1,v2)
            return v2[field]<v1[field];
        end)
    end
    return tab;
end

--table相关
---------------------------
--查询指定元素在数组中的位置
---------------------------
function utils:indexOf(array,item)
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
function utils:remove(array,item)
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
function utils:indexOfByKey(array, key, cond)
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
function utils:merge(array1, array2)
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
function utils:tableAddAttr(tab, key, value)
    for _, var in pairs(tab) do
        var[key] = value;
    end
end
 
function utils:dump(value, desciption, nesting)
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
function utils:convertTo32(number)
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
 