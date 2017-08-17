local skynet = require "skynet"
local command = {}
local reptile_services = {}

local address
function command.Init()
    command.search_url = "http://zhannei.baidu.com/cse/search?s=920895234054625192&entry=1&q="
    address = skynet.newservice("reptile")
    command.Search("圣墟")
end

function command.Search(text)
    local url = command.search_url .. text
    skynet.send(address,"lua","LoadURL",url) 
end

return command