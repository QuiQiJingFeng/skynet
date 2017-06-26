-----------------------------------------------------------------//--
-- @file	csv.lua
-- @date	2014.11.10
-- @author	Louis Huang | louis.huang@yqidea.com
-- @note	Use to decode a CSV file
--
-- This software is supplied under the terms of a license
-- agreement or nondisclosure agreement with YQIdea and may
-- not be copied or disclosed except in accordance with the
-- terms of that agreement.
--
-- 2014 YQidea.com All Rights Reserved.
--------------------------------------------------------------------/

-- record the type of every column
local _type
local sep = ","

local function _parse_csv_line(line, key_col, keys)
    local res = {}
    local pos = 1
    local index = 1
    local key

    if keys then
        local startp, endp = string.find(line, sep, pos)
        local id_text = string.sub(line, 1, startp-1)

        if id_text == "" then
            --忽略注释行
            return

        else
            res[keys[index]] = tonumber(id_text)
            pos = startp + 1
            index = index + 1

            key = tonumber(id_text)
        end
    end

    while true do
        local c = string.sub(line, pos, pos)
        local text = ""
        --if (c == "") then break end
        if (c == '"') then
            -- quoted value (ignore separator within)
            txt = ""
            repeat
                local startp,endp = string.find(line,'^%b""',pos)
                txt = txt..string.sub(line,startp+1,endp-1)
                pos = endp + 1
                c = string.sub(line,pos,pos)
                if (c == '"') then txt = txt..'"' end
                -- check first char AFTER quoted string, if it is another
                -- quoted string without separator, then append it
                -- this is the way to "escape" the quote char in a quote. example:
                --   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
            until (c ~= '"')
            if keys ~= nil then
                res[keys[index]] = txt
            else
                table.insert(res, txt)
            end
            assert(c == sep or c == "")

            pos = pos + 1
            index = index + 1
        else
            -- no quotes used, just look for the first separator
            local startp, endp = string.find(line,sep,pos)
            if startp then
                txt = string.sub(line,pos,startp-1)
                if keys then
                    if _type[index] == "number" then
                        txt = tonumber(txt) and tonumber(txt) or 0
                    elseif _type[index] == "boolean" then
                        txt = txt == "1" and true or false
                    end

                    res[keys[index]] = txt
                else
                    table.insert(res, txt)
                end

                pos = endp + 1
                index = index + 1
            else
                -- no separator found -> use rest of string and terminate
                txt = string.sub(line,pos)
                if keys then
                    if _type[index] == "number" then
                        txt = tonumber(txt) and tonumber(txt) or 0

                    elseif _type[index] == "boolean" then
                        txt = txt == "1" and true or false
                    end

                    res[keys[index]] = txt
                else
                    table.insert(res, txt)
                end

                break
            end
        end
    end
    --添加数组和table的写法  使用符号 ; = 
    for k,v in pairs(res) do
        local exist = string.find(v,";")
        if exist then
            local istb = string.find(v,"=")
            if istb then
                v = string.gsub(v, ";", ",")
                f = load("return {"..v.."}")
                res[k] = f()
            else
                v = string.gsub(v, ";", ",")
                f = load("return {"..v.."}")
                res[k] = f()
            end
        end
    end

    return res, key
end

-- check the type of every column
-- the type of the first column must be "number"
local function _check_data_type(types, col,path)
    if(types[col] ~= "number") then
        error("\nError:"..types[col].."!!!The type of \"ID\"(1st column ) must be number!")
    end

    local pattern = {"number", "string", "boolean"}
    for k, v in pairs(types) do
        if v ~= pattern[1] and v ~= pattern[2] and v ~= pattern[3] then
            error("\nError: The table"..path..", "..k.."st column's type \""..v.."\" is error！！this table just suport the type like:\"number\" or \"string\"")
        end
    end
end

-- check the name of every colume
-- the name of the first column must be "ID"
local function _check_col_name(keys, col,path)
    if(keys[col] ~= "ID") then
        error("\nError:\"table:"..path..", "..keys[col].."\"!The first column must be \"ID\"!")
    end

    for k, v in pairs(keys) do
        local i = k + 1
        while keys[i] do
            if(v == keys[i]) then
                error("\nError:\"table:"..path..", "..v.."\" The name of column".. k .." and column"..i.." are repeated!!!");
            end
            i = i + 1
        end
    end
end

--check the type of every cell
local function _check_cell (res,keys,row)
    local index = 1
    while true do
        if keys[index] ~= nil then
            local cell = res[keys[index]]
            if cell == nil and _type[index] == "number" then
                error("\nError: row "..row..",col "..index.." is nil")
            elseif cell ~= nil and _type[index] ~= type(cell) then
                error("\nError: cell"..cell..",Type of row "..row..",col "..index)
            end
            index = index + 1
        else
            break
        end
    end
end

---
-- Interface
---
local csv = {}

function csv.load(path)
    local key_row = 3	-- key for each column
    local key_col = 1	-- key for each row

    local fp = io.open(path, "r")
    if not fp then
        return
    end
    local line_num = 1
    local res = {}
    _type = {}
    local keys
    local line = fp:read()
    while line ~= nil do
        --	print("表的line",path,line)
        if string.find(line, "\r", -1) then
            line = string.sub(line, 1, -2)
        end

        if line_num > key_row then
            local row, key = _parse_csv_line(line, key_col, keys)
            --_check_cell(row,keys,key)
            if key then
                res[key] = row
            end

        elseif line_num == key_row then
            --解析字段名
            keys = _parse_csv_line(line, key_col)
            _check_col_name(keys, key_col,path)

        elseif(line_num == key_row - 1) then
            --解析类型
            _type =  _parse_csv_line(line, key_col)
            _check_data_type(_type, key_col, path)
        end

        line = fp:read()
        line_num = line_num + 1
    end

    fp:close()

    return res
end

return csv
