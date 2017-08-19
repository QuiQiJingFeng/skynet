local skynet = require "skynet"
local socket = require "socket"
local table = table
local string = string

local command = {}
function command:Init()
    self.reptile_services = {}
    self.libcurl_service = {}
    for i = 1,100 do
        self.reptile_services[i] = skynet.newservice("reptile")
    end 
    for i = 1,100 do
        self.libcurl_service[i] = skynet.newservice("libcurl")
    end 
    self:ListenWeb()
end

function command:ListenWeb()
    local balance = 1
    local game_port = 8888
    local id = socket.listen("0.0.0.0", game_port) 
    skynet.error("Watchdog listen on", game_port) 
	socket.start(id , function(id, addr)  
		-- 当一个 http 请求到达的时候, 把 socket id 分发到事先准备好的代理中去处理。
		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, self.reptile_services[balance]))
		skynet.send(self.reptile_services[balance], "lua","Process", id,self.libcurl_service[balance])
		balance = balance + 1
		if balance > #self.reptile_services then
			balance = 1
		end
	end)
end

return command