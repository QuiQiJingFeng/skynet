local config_manager = require "config_manager"

local resource_center = {}

function resource_center:Init()
    self.resource_list = {}
    for i=1,config_manager.resource_config.length do
        self.resource_list[i] = 0
    end
end

function resource_center:Save()

end

function resource_center:Close()
    
end


return resource_center