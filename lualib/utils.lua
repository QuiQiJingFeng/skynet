local utils = {} 

--将秒数转换成日期
function utils:convertToDate(seconds)
  return os.date("%Y/%m/%d %H:%M:%S",math.ceil(seconds));
end

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
    local index=self:indexOf(array,item);
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


---------------------------
--XML解析
-- 1.2 - Created new structure for returned table
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
---------------------------
function utils:newParser()

    local XmlParser = {};

    function XmlParser:ToXmlString(value)
        value = string.gsub(value, "&", "&amp;"); -- '&' -> "&amp;"
        value = string.gsub(value, "<", "&lt;"); -- '<' -> "&lt;"
        value = string.gsub(value, ">", "&gt;"); -- '>' -> "&gt;"
        value = string.gsub(value, "\"", "&quot;"); -- '"' -> "&quot;"
        value = string.gsub(value, "([^%w%&%;%p%\t% ])",
            function(c)
                return string.format("&#x%X;", string.byte(c))
            end);
        return value;
    end

    function XmlParser:FromXmlString(value)
        value = string.gsub(value, "&#x([%x]+)%;",
            function(h)
                return string.char(tonumber(h, 16))
            end);
        value = string.gsub(value, "&#([0-9]+)%;",
            function(h)
                return string.char(tonumber(h, 10))
            end);
        value = string.gsub(value, "&quot;", "\"");
        value = string.gsub(value, "&apos;", "'");
        value = string.gsub(value, "&gt;", ">");
        value = string.gsub(value, "&lt;", "<");
        value = string.gsub(value, "&amp;", "&");
        return value;
    end

    function XmlParser:ParseArgs(node, s)
       local abc = string.gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
            node:addProperty(w, self:FromXmlString(a))
        end)
    end

    function XmlParser:ParseXmlText(xmlText)
        local stack = {}
        local top = self:newNode()  
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
            if not ni then break end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top:value() or "") .. self:FromXmlString(text)
                stack[#stack]:setValue(lVal)
            end
            if empty == "/" then -- empty element tag
                local lNode = self:newNode(label)
                self:ParseArgs(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then -- start tag
                local lNode = self:newNode(label)
                self:ParseArgs(lNode, xarg)
                table.insert(stack, lNode)
        top = lNode
            else -- end tag
                local toclose = table.remove(stack) -- remove top

                top = stack[#stack]
                if #stack < 1 then
                    error("XmlParser: nothing to close with " .. label)
                end
                if toclose:name() ~= label then
                    error("XmlParser: trying to close " .. toclose.name .. " with " .. label)
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        local text = string.sub(xmlText, i);
        if #stack > 1 then
            error("XmlParser: unclosed " .. stack[#stack]:name())
        end
        return top
    end

    function XmlParser:loadFile(path)
        local hFile, err = io.open(path, "r");

        if hFile and not err then
            local xmlText = hFile:read("*a"); -- read file content
            io.close(hFile);
            return self:ParseXmlText(xmlText), nil;
        else
            print(err)
            return nil
        end
    end

    return XmlParser
end

function utils:newNode(name) 
    local node = {}
    node.___value = nil
    node.___name = name
    node.___children = {}
    node.___props = {}

    function node:value() return self.___value end
    function node:setValue(val) self.___value = val end
    function node:name() return self.___name end
    function node:setName(name) self.___name = name end
    function node:children() return self.___children end
    function node:numChildren() return #self.___children end
    function node:addChild(child)
        if self[child:name()] ~= nil then
            if type(self[child:name()].name) == "function" then
                local tempTable = {}
                table.insert(tempTable, self[child:name()])
                self[child:name()] = tempTable
            end
            table.insert(self[child:name()], child)
        else
            self[child:name()] = child
        end
        table.insert(self.___children, child)
    end

    function node:properties() return self.___props end
    function node:numProperties() return #self.___props end
    function node:addProperty(name, value)
        local lName = "@" .. name
        if self[lName] ~= nil then
            if type(self[lName]) == "string" then
                local tempTable = {}
                table.insert(tempTable, self[lName])
                self[lName] = tempTable
            end
            table.insert(self[lName], value)
        else
            self[lName] = value
        end
        table.insert(self.___props, { name = name, value = self[name] })
    end

    return node
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

function utils:decode(s,startPos) 
    function decode_scanWhitespace(s,startPos)
      local whitespace=" \n\r\t"
      local stringLen = string.len(s)
      while ( string.find(whitespace, string.sub(s,startPos,startPos), 1, true)  and startPos <= stringLen) do
        startPos = startPos + 1
      end
      return startPos
    end
    function decode_scanObject(s,startPos)
      local object = {}
      local stringLen = string.len(s)
      local key, value
      assert(string.sub(s,startPos,startPos)=='{','decode_scanObject called but object does not start at position ' .. startPos .. ' in string:\n' .. s)
      startPos = startPos + 1
      repeat
        startPos = decode_scanWhitespace(s,startPos)
        assert(startPos<=stringLen, 'JSON string ended unexpectedly while scanning object.')
        local curChar = string.sub(s,startPos,startPos)
        if (curChar=='}') then
          return object,startPos+1
        end
        if (curChar==',') then
          startPos = decode_scanWhitespace(s,startPos+1)
        end
        assert(startPos<=stringLen, 'JSON string ended unexpectedly scanning object.')
        -- Scan the key
        key, startPos = self:decode(s,startPos)
        assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
        startPos = decode_scanWhitespace(s,startPos)
        assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
        assert(string.sub(s,startPos,startPos)==':','JSON object key-value assignment mal-formed at ' .. startPos)
        startPos = decode_scanWhitespace(s,startPos+1)
        assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
        value, startPos = self:decode(s,startPos)
        object[key]=value
      until false   -- infinite loop while key-value pairs are found
    end
    function decode_scanArray(s,startPos)
      local array = {}  -- The return value
      local stringLen = string.len(s)
      assert(string.sub(s,startPos,startPos)=='[','decode_scanArray called but array does not start at position ' .. startPos .. ' in string:\n'..s )
      startPos = startPos + 1
      -- Infinite loop for array elements
      repeat
        startPos = decode_scanWhitespace(s,startPos)
        assert(startPos<=stringLen,'JSON String ended unexpectedly scanning array.')
        local curChar = string.sub(s,startPos,startPos)
        if (curChar==']') then
          return array, startPos+1
        end
        if (curChar==',') then
          startPos = decode_scanWhitespace(s,startPos+1)
        end
        assert(startPos<=stringLen, 'JSON String ended unexpectedly scanning array.')
        object, startPos = decode(s,startPos)
        table.insert(array,object)
      until false
    end

    function decode_scanNumber(s,startPos)
      local endPos = startPos+1
      local stringLen = string.len(s)
      local acceptableChars = "+-0123456789.e"
      while (string.find(acceptableChars, string.sub(s,endPos,endPos), 1, true)
        and endPos<=stringLen
        ) do
        endPos = endPos + 1
      end
      local stringValue = 'return ' .. string.sub(s,startPos, endPos-1)
      local stringEval = loadstring(stringValue)
       assert(stringEval, 'Failed to scan number [ ' .. stringValue .. '] in JSON string at position ' .. startPos .. ' : ' .. endPos)
      return stringEval(), endPos
    end
    function decode_scanString(s,startPos)
      assert(startPos, 'decode_scanString(..) called without start position')
      local startChar = string.sub(s,startPos,startPos)
      assert(startChar==[[']] or startChar==[["]],'decode_scanString called for a non-string')
      local escaped = false
      local endPos = startPos + 1
      local bEnded = false
      local stringLen = string.len(s)
      repeat
        local curChar = string.sub(s,endPos,endPos)
        if not escaped then
          if curChar==[[\]] then
            escaped = true
          else
            bEnded = curChar==startChar
          end
        else
          -- If we're escaped, we accept the current character come what may
          escaped = false
        end
        endPos = endPos + 1
        assert(endPos <= stringLen+1, "String decoding failed: unterminated string at position " .. endPos)
      until bEnded
      local stringValue = 'return ' .. string.sub(s, startPos, endPos-1)
      local stringEval = loadstring(stringValue)
      assert(stringEval, 'Failed to load string [ ' .. stringValue .. '] in JSON4Lua.decode_scanString at position ' .. startPos .. ' : ' .. endPos)
      return stringEval(), endPos
    end
    function decode_scanComment(s, startPos)
      assert( string.sub(s,startPos,startPos+1)=='/*', "decode_scanComment called but comment does not start at position " .. startPos)
      local endPos = string.find(s,'*/',startPos+2)
      assert(endPos~=nil, "Unterminated comment in string at " .. startPos)
      return endPos+2
    end
    function decode_scanConstant(s, startPos)
      local consts = { ["true"] = true, ["false"] = false, ["null"] = nil }
      local constNames = {"true","false","null"}

      for i,k in pairs(constNames) do
        --print ("[" .. string.sub(s,startPos, startPos + string.len(k) -1) .."]", k)
        if string.sub(s,startPos, startPos + string.len(k) -1 )==k then
          return consts[k], startPos + string.len(k)
        end
      end
      assert(nil, 'Failed to scan constant from string ' .. s .. ' at starting position ' .. startPos)
    end



      startPos = startPos and startPos or 1
      startPos = decode_scanWhitespace(s,startPos)
      assert(startPos<=string.len(s), 'Unterminated JSON encoded object found at position in [' .. s .. ']')
      local curChar = string.sub(s,startPos,startPos)
      -- Object
      if curChar=='{' then
        return decode_scanObject(s,startPos)
      end
      -- Array
      if curChar=='[' then
        return decode_scanArray(s,startPos)
      end
      -- Number
      if string.find("+-0123456789.e", curChar, 1, true) then
        return decode_scanNumber(s,startPos)
      end
      -- String
      if curChar==[["]] or curChar==[[']] then
        return decode_scanString(s,startPos)
      end
      if string.sub(s,startPos,startPos+1)=='/*' then
        return self:decode(s, decode_scanComment(s,startPos))
      end
      -- Otherwise, it must be a constant
      return decode_scanConstant(s,startPos)
end

return utils;
 