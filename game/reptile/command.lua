local skynet = require "skynet"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local socket = require "socket"
local event_dispatcher = require "event_dispatcher"
local cjson = require "cjson"
local command = {}

local header = {
    ['Content-Type']='application/json',
    ['Access-Control-Allow-Origin']='*'
}

function command:Init()
    event_dispatcher:Init()
    self.search_url = "zhannei.baidu.com/cse/search?s=920895234054625192&entry=1&q="
    -- Search?text=圣墟
    event_dispatcher:RegisterEvent("/Search",function(service_id,id,body) 
        if body.text then
            local data = self:Search(service_id,body.text)
            self:Response(id,200, cjson.encode(data))
        else
            self:Response(id,404, "ERROR")
        end
    end)

    event_dispatcher:RegisterEvent("/ChapterList",function(service_id,id,body) 
        if body.url then
            local data = self:ChapterList(service_id,body.url)
            self:Response(id,200, cjson.encode(data))
        else
            self:Response(id,404, "ERROR")
        end
    end)

    event_dispatcher:RegisterEvent("/Content",function(service_id,id,body) 
        if body.url then
            local data = self:Content(service_id,body.url)
            self:Response(id,200, cjson.encode(data))
        else
            self:Response(id,404, "ERROR")
        end
    end)
end

function command:ChapterList(service_id,url)
    local success,content = skynet.call(service_id,"lua","Request",url)
    local ret = {result={}}
    if success then
        local patern = [[<dd> <a style="" href="(.-)">(.-)</a><]]
        for chapter_link,chapter_name in string.gmatch(content,patern) do
            chapter_link = "http://www.qu.la" .. chapter_link
            local data = {
                            chapter_link=chapter_link,chapter_name=chapter_name
                        }
            table.insert(ret.result,data)
        end
        ret.success = true
        return ret
    end
    return ret
end

function command:Content(service_id,url)
    local success,content = skynet.call(service_id,"lua","Request",url)
    local ret = {}
    if success then
        local patern = [[<div id="content">(.-)</div>]]
        for content in string.gmatch(content,patern) do
            content = string.gsub(content,"&nbsp;","")
            content = string.gsub(content,"<br.->","\n")
            ret.content = content
            break;
        end
        ret.success = true
        return ret
    end
    return ret
end

function command:Search(service_id,text)
    local success,content = skynet.call(service_id,"lua","Request",self.search_url..text)
    local ret = {result={}}
    if success then
        local patern = [[<div class="result%-item result%-game%-item">.-"img" href="(http.-/)".-<img src="(http.-jpg).-<a cpos="title".-title="(.-)".-<p class="result%-game%-item%-desc">(.-)</p>.-</span>.-<span>(.-)</span>.-<span class="result%-game%-item%-info%-tag%-title">(.-)</span>.-<span class="result%-game%-item%-info%-tag%-title">(.-)</span>]]
        for link,img_url,name,desc,author,type in string.gmatch(content,patern) do
            author = string.gsub(author," ","")
            author = string.gsub(author,"\n","")
            local data = {
                            link=link,img_url=img_url,name=name,desc=desc,
                            author=author,type=type
                        }
            table.insert(ret.result,data)
        end
        ret.success = true
        return ret
    end
    return ret
end

--WEB PROCESS
function command:Response(id, statuscode, bodyfunc)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), statuscode, bodyfunc, header)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

function command:Process(id,service_id)
    socket.start(id)  -- 开始接收一个 socket
    -- limit request body size to 8192 (you can pass nil to unlimit)
    -- 一般的业务不需要处理大量上行数据，为了防止攻击，做了一个 8K 限制。这个限制可以去掉。
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
            print("F000000")
			if code ~= 200 then  -- 如果协议解析有问题，就回应一个错误码 code 。
				self:Response(id, code)
			else
				-- 这是一个示范的回应过程，你可以根据你的实际需要，解析 url, method 和 header 做出回应。
				local tmp = {}
				if header.host then
					table.insert(tmp, string.format("host: %s", header.host))
				end
				local path, query = urllib.parse(url)
                local body = {}
				if query then
					body = urllib.parse_query(query)
				end
                event_dispatcher:DispatchEvent(path,service_id,id,body)
			end
		else
			-- 如果抛出的异常是 sockethelper.socket_error 表示是客户端网络断开了。
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
end

return command