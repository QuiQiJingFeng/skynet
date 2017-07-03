local redis = require "redis"
local sharedata = require "sharedata"
local cjson = require "cjson"
local name_to_id = {}

local social = {}

function social:Init()
    self.relations = {}

    self.union_db = redis.connect(sharedata.query("redis_conf_2"))

    self:Load()
end
---------------------------------------------------------------
--加载数据  social:all_relations=>[5YC1U,5YC1X...]  social:relations:5YC1U=>INFO
---------------------------------------------------------------
function social:Load()
    local relations_key = "social:all_relations"
    local data = self.union_db:lrange(relations_key,0,-1)
    for _,user_id in ipairs(data) do
        local user_key = "social:relations:"..user_id
        local info = self.union_db:hgetall(user_key)
        local temp = {}
        for i=1,#info,2 do
            local key,value = info[i],info[i+1]
            if key == "friends" or key == "invitations" then
                value = cjson.decode(value)
            end
            temp[key] = value
        end
        self.relations[user_id] = temp
    end
end

local COMMAND = {}
---------------------------------------------------------------
--检查是否是已经存在该名称,如果不存在返回nil,存在则返回id
---------------------------------------------------------------
function COMMAND.CheckNewName(name,user_id)
    local id = name_to_id[name]
    if not id then
        name_to_id[name] = user_id
    end
    return id
end
---------------------------------------------------------------
--每个(创建完角色的玩家)必须都记录在social中,用来添加好友
---------------------------------------------------------------
function COMMAND.NewUser(user_id,name,role_id)
    social.relations[user_id] = {
        role_id = role_id,      --主角ID
        name = name,            --主角名称
        friends = {},       --好友列表
        invitations = {},       --好友申请列表
        logout_time = nil       --记录登出的时间,如果为nil,则为在线
    }
    local all_relations_key = "social:all_relations"
    self.union_db:lpush(social.all_relations,user_id)
    local user_key = "social:relations:"..user_id 
    self.union_db:hmset(user_key,"role_id",role_id,"name",name)
end
---------------------------------------------------------------
--更新玩家的登出时间
---------------------------------------------------------------
function COMMAND.UpdateLogoutTime(user_id,time)
    local info = social.relations[user_id]
    if info then
        info.logout_time = time
        local user_key = "social:relations:" .. user_id 
        self.union_db:hmset(user_key,"logout_time",time)
    end
end
---------------------------------------------------------------
--更新玩家的角色ID
---------------------------------------------------------------
function COMMAND.UpdateRoleID(user_id,role_id)
    local info = social.relations[user_id]
    if info then
        info.role_id = role_id
        local user_key = "social:relations:" .. user_id 
        self.union_db:hmset(user_key,"role_id",role_id)
    end

end
---------------------------------------------------------------
--更新玩家的名称
---------------------------------------------------------------
function COMMAND.UpdateUserName(user_id,name)
    local info = social.relations[user_id]
    if info then
        info.name = name
        local user_key = "social:relations:" .. user_id 
        self.union_db:hmset(user_key,"name",name)
    end
end
---------------------------------------------------------------
--发送好友邀请
---------------------------------------------------------------
function COMMAND.MakeInvitation(src_user_id, dest_user_id)
    if src_user_id == dest_user_id then
        return "same_id"
    end
    local src_friend_info = social.relations[src_user_id]
    if not src_friend_info then
        return "not_find_src_friend_info"
    end
    local dest_friend_info = social.relations[dest_user_id]
    if not dest_friend_info then
        return "no_find_dest_friend_info"
    end

    local invite = dest_friend_info.invitations[src_user_id]
    if invite then
        return "already_invite"
    end

    local is_friend = src_friend_info.friends[dest_user_id]
    if is_friend then
        return "already_friend"
    end
 
    --加入到对方的 申请列表
    dest_friend_info.invitations[src_user_id] = true
    local user_key = "social:relations:" .. dest_user_id 
    self.union_db:hmset(user_key,"invitations",cjson.encode(dest_friend_info.invitations))

    --通知对方刷新申请列表
    local agent = skynet.call(".agent_manager", "lua", "GetAgentByUserId", dest_user_id)
    if agent then
        skynet.send(agent, "lua", "NewInvitation", src_friend_info)
    end
    return "success"
end
---------------------------------------------------------------
--接受好友申请
---------------------------------------------------------------
function COMMAND.AcceptInvite(src_user_id, dest_user_id)
    if src_user_id == dest_user_id then
        return "same_id"
    end

    local src_friend_info = social.relations[src_user_id]
    if not src_friend_info then
        return "not_find_src_friend_info"
    end

    local a_invitation = src_friend_info.invitations[dest_user_id]
    if not a_invitation then
        return "failure"
    end
 
    local dest_friend_info = social.relations[dest_user_id]
    if not dest_friend_info then
        return "no_find_dest_friend_info"
    end
    --绑定好友关系
    src_friend_info.friends[dest_user_id] = true
    dest_friend_info.friends[src_user_id] = true
    src_friend_info.invitations[dest_user_id] = nil


    local src_user_key = "social:relations:" .. src_user_id 
    self.union_db:hmset(src_user_key,"friends",cjson.encode(src_friend_info.friends))

    local dest_user_key = "social:relations:" .. dest_user_id 
    self.union_db:hmset(dest_user_key,"friends",cjson.encode(dest_friend_info.friends),
                        "invitations",cjson.encode(src_friend_info.invitations))

    if dest_friend_info.invitations[src_user_id] then
        dest_friend_info.invitations[src_user_id] = nil
        self.union_db:hmset(dest_user_key,"invitations",cjson.encode(dest_friend_info.invitations))
    end
    --通知对方,我已经同意加对方为好友
    local agent = skynet.call(".agent_manager", "lua", "GetAgentByUserId", dest_user_id)
    if agent then
        skynet.send(agent, "lua", "NewFriend", src_friend_info)
    end
    return "success"
end
---------------------------------------------------------------
--拒绝好友申请
---------------------------------------------------------------
function COMMAND.RefuseInvite(src_user_id, dest_user_id)
    local src_friend_info = social.relations[src_user_id]
    if not src_friend_info then
        return "not_find_src_friend_info"
    end

    if not src_friend_info.invitations[dest_user_id] then
        return "failure"
    end

    src_friend_info.invitations[dest_user_id] = nil

    local src_user_key = "social:relations:" .. src_user_id 
    self.union_db:hmset(src_user_key,"invitations",cjson.encode(src_friend_info.invitations))

    return "success"
end

---------------------------------------------------------------
--删除好友
---------------------------------------------------------------
function COMMAND.RemoveFriend(src_user_id, dest_user_id)
    local src_friend_info = social.relations[src_user_id]
    if not src_friend_info then
        return "not_find_src_friend_info"
    end

    if not src_friend_info.friends[dest_user_id] then
        return "failure"
    end

    src_friend_info.friends[dest_user_id] = nil
    local src_user_key = "social:relations:" .. src_user_id 
    self.union_db:hmset(src_user_key,"friends",cjson.encode(src_friend_info.friends))

    local dest_friend_info = social.relations[dest_user_id]
    if dest_friend_info and dest_friend_info.friends[src_user_id] then
        dest_friend_info.friends[src_user_id] = nil

        local dest_user_key = "social:relations:" .. dest_user_id 
        self.union_db:hmset(dest_user_key,"friends",cjson.encode(dest_friend_info.friends))

        --通知对方删除好友
        local agent = skynet.call(".notice_center", "lua", "GetAgentByUserId", dest_user_id)
        if agent then
            skynet.send(agent, "lua", "RemoveFriend", src_user_id)
        end
    end

    return "success"
end
---------------------------------------------------------------
--查询用户好友信息 如果有则返回,如果没有返回nil
---------------------------------------------------------------
function COMMAND.QueryUserInfo(user_id)
    return social.relations[user_id]
end
return social,COMMAND