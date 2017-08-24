local skynet = require "skynet"
local socket = require "skynet.socket"

local NUMBER = 1000000

local function server()
	local tb = {}
	local host
	host = socket.udp(function(str, from)
		-- print("server recv", str, socket.udp_address(from))
		
		if str == "END" then
			for i=1,NUMBER do
				if not tb[i] then
					print("MISS: ",i)
				end
			end
			print("FYD=====END")
		else
			tb[tonumber(str)] = tonumber(str)
			socket.sendto(host, from, str)
		end
	end , "127.0.0.1", 8888)	-- bind an address
end

-- local function client()
-- 	local c = socket.udp(function(str, from)
-- 		-- print("client recv", str, socket.udp_address(from))
-- 	end)
-- 	socket.udp_connect(c, "47.52.99.120:8888", 8888)

-- 	for i=1,NUMBER do
-- 		socket.write(c, tostring(i))	-- write to the address by udp_connect binding
-- 	end
-- 	socket.write(c, "END")
-- end

skynet.start(function()
	skynet.fork(server)
	-- skynet.fork(client)
end)