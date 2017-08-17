local skynet = require "skynet"
local command = {}

function command.Init()

end

function command.LoadURL(url)
        -- print(url,"-----------BEGAIN------------")
    local success,content = skynet.call(".logind","lua", "Request", url)
    if success then
        local result = {}
        local patern = [[<div class="result%-item result%-game%-item">.-"img" href="(http.-/)".-<img src="(http.-jpg).-<a cpos="title".-title="(.-)".-<p class="result%-game%-item%-desc">(.-)</p>.-<span>(.-)</span>.-<span class="result%-game%-item%-info%-tag%-title">(.-)</span>.-<span class="result%-game%-item%-info%-tag%-title">(.-)</span>.-<a cpos="newchapter" href="(.-)".->(.-)</a>]]
        for link,img_url,name,desc,author,type,update_time,new_chapter_link,newchapter_name in string.gmatch(content,patern) do
            local data = {
                            link=link,img_url=img_url,name=name,desc=desc,
                            author=author,type=type,update_time=update_time,
                            new_chapter_link=new_chapter_link,
                            newchapter_name=newchapter_name
                        }
            table.insert(result,data)
        end
        for k,data in pairs(result) do
            for k,v in pairs(data) do
                print(k,v)
            end
        end
    end
end

return command