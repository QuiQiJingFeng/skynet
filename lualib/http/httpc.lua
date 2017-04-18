local skynet = require "skynet"
local socket = require "http.sockethelper"
local url = require "http.url"
local internal = require "http.internal"
local dns = require "dns"
local string = string
local table = table

local httpc = {}

local function request(fd, method, host, url, recvheader, header, content)
	local read = socket.readfunc(fd)
	local write = socket.writefunc(fd)
	local header_content = ""
	if header then
		if not header.host then
			header.host = host
		end
		for k,v in pairs(header) do
			header_content = string.format("%s%s:%s\r\n", header_content, k, v)
		end
	else
		header_content = string.format("host:%s\r\n",host)
	end

	if content then
		local data = string.format("%s %s HTTP/1.1\r\n%scontent-length:%d\r\n\r\n", method, url, header_content, #content)
		write(data)
		write(content)
	else
		local request_header = string.format("%s %s HTTP/1.1\r\n%scontent-length:0\r\n\r\n", method, url, header_content)
		write(request_header)
	end

	local tmpline = {}
	local body = internal.recvheader(read, tmpline, "")
	if not body then
		error(socket.socket_error)
	end

	local statusline = tmpline[1]
	local code, info = statusline:match "HTTP/[%d%.]+%s+([%d]+)%s+(.*)$"
	code = assert(tonumber(code))

	local header = internal.parseheader(tmpline,2,recvheader or {})
	if not header then
		error("Invalid HTTP response header")
	end

	local length = header["content-length"]
	if length then
		length = tonumber(length)
	end
	local mode = header["transfer-encoding"]
	if mode then
		if mode ~= "identity" and mode ~= "chunked" then
			error ("Unsupport transfer-encoding")
		end
	end

	if mode == "chunked" then
		body, header = internal.recvchunkedbody(read, nil, header, body)
		if not body then
			error("Invalid response body")
		end
	else
		-- identity mode
		if length then
			if #body >= length then
				body = body:sub(1,length)
			else
				local padding = read(length - #body)
				body = body .. padding
			end
		else
			-- no content-length, read all
			body = body .. socket.readall(fd)
		end
	end

	return code, body
end

local async_dns

function httpc.dns(server,port)
	async_dns = true
	dns.server(server,port)
end

function httpc.request(method, host, url, recvheader, header, content)
	local timeout = httpc.timeout	-- get httpc.timeout before any blocked api
	local hostname, port = host:match"([^:]+):?(%d*)$"
	if port == "" then
		port = 80
	else
		port = tonumber(port)
	end
	if async_dns and not hostname:match(".*%d+$") then
		hostname = dns.resolve(hostname)
	end
	local fd = socket.connect(hostname, port)
	local finish
	if timeout then
		skynet.timeout(timeout, function()
			if not finish then
				local temp = fd
				fd = nil
				socket.close(temp)
			end
		end)
	end
	local ok , statuscode, body = pcall(request, fd,method, host, url, recvheader, header, content)
	finish = true
	if fd then	-- may close by skynet.timeout
		socket.close(fd)
	end
	if ok then
		return statuscode, body
	else
		error(statuscode)
	end
end

function httpc.get(...)
	return httpc.request("GET", ...)
end

local function escape(s)
	return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function httpc.post(host, url, form, recvheader)
	local header = {
		["content-type"] = "application/x-www-form-urlencoded"
	}
	local body = {}
	for k,v in pairs(form) do
		table.insert(body, string.format("%s=%s",escape(k),escape(v)))
	end

	return httpc.request("POST", host, url, recvheader, header, table.concat(body , "&"))
end

return httpc

--REDEME:FYD  http模块
--[[

	skynet 提供了一个非常简单的 http 客户端模块。你可以用:
	httpc.request(method, host, uri, recvheader, header, content, timeout)
	来提交一个 http 请求，其中
		method 是 "GET" "POST" 等。
		host 为目标机的地址
		uri 为请求的 URI
		recvheader 可以是 nil 或一张空表，用于接收回应的 http 协议头。
		header 是自定义的 http 请求头。注：如果 header 中没有给出 host ，那么将用前面的 host 参数自动补上。
		content 为请求的内容。
		timeout 是一个请求的超时设置，如果没有会使用 httpc.timeout 来做为默认值，这个超时是指整个过程，包括连接，获取数据等它返回状态码和内容。如果网络出错，则抛出 error 。

	httpc.dns([server, port])

	可以用来设置一个异步查询 dns 的服务器地址。如果你不给出地址，那么将从 /etc/resolv.conf 查找地址。
	如果你没有调用它设置异步 dns 查询，那么 skynet 将在网络底层做同步查询。
	这很有可能阻塞住整个 skynet 的网络消息处理（不仅仅阻塞单个 skynet 服务）。

	另外，httpc 还提供了简单的 httpc.get 以及 httpc.post 的封装

	httpc 可以通过设置 httpc.timeout 的值来控制超时时间。时间单位为 1/100 秒。

	example:
		local header = {
		    ["content-type"] = "application/x-www-form-urlencoded"
		}
		local content = "app=xxxx&channel=44&serverId=1&accountId=arggr"
		local host = "127.0.0.1"
		local succ, status, post_ret = pcall(httpc.request, "POST", host, "/webservice/request.php", {}, header, content)
		
]]
