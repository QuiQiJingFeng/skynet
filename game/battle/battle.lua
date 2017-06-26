local sharedata = require "sharedata"


local battle = {}
function battle:LoadDefault()
    self.skill_config = sharedata.query("skill_config")
    

end

local COMMAND = {}



return battle,COMMAND