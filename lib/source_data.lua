-- Downloaded source is parsed as data in the worker, never executed as Lua.
local json=require('json')
local manifest
local M={revision=0,current=nil}
local function norm(s)return s:lower():gsub('[^a-z0-9]','')end
local function integer(n,min,max)return type(n)=='number' and n==math.floor(n) and n>=min and n<=max end
local function read(path)
    local f=io.open(path,'rb');if not f then return nil end
    local body=f:read('*a');f:close()
    if #body>8*1024*1024 then return nil end
    local ok,data=pcall(json.decode,body)
    if ok and type(data)=='table' then return data,body end
end
function M.init(path)
    M.path=path
    local data=read(path..'/data/update_manifest.json')
    if not data or type(data.quests)~='table' then return false end
    manifest={ids={},titles={}}
    for _,q in ipairs(data.quests) do
        manifest.ids[q.group..':'..q.id]=q
        manifest.titles[q.group..':'..norm(q.title)]=q
    end
    local saved=read(path..'/cache/source-data-current.json')
    if not saved or not M.validate(saved) then saved=read(path..'/cache/source-data-current.json.bak') end
    if saved then local valid=M.validate(saved);if valid then M.apply(valid) end end
    return true
end
function M.validate(data)
    if not manifest or type(data)~='table' or data.schema~=1 or type(data.sha)~='string' or
        #data.sha~=40 or data.sha:find('[^a-f0-9]') or not integer(data.time,1,9999999999) or
        type(data.npcs)~='table' or type(data.items)~='table' or type(data.repeatTurnins)~='table' then
        return nil,'Invalid source bundle.'
    end
    local result={sha=data.sha,time=data.time,npcs={},items={},repeatTurnins={}}
    if #data.npcs<50 or #data.npcs>2000 then return nil,'Unexpected NPC coverage.' end
    for _,q in ipairs(data.npcs) do
        if type(q)~='table' or type(q.group)~='string' or not integer(q.id,0,255) then return nil,'Invalid quest identity.' end
        local approved=manifest.ids[q.group..':'..q.id]
        if not approved or q.title~=approved.title or not integer(q.zone,1,1023) or
            type(q.npc)~='string' or #q.npc<1 or #q.npc>80 or q.npc:find('[%c]') then return nil,'Unapproved NPC quest.' end
        result.npcs[#result.npcs+1]=q
    end
    local itemCount=0
    for key,entries in pairs(data.items) do
        local id=tonumber(key)
        if not integer(id,1,65535) or id==4094 or type(entries)~='table' or #entries>500 then return nil,'Invalid item reference.' end
        result.items[id]={};itemCount=itemCount+1
        for _,q in ipairs(entries) do
            if type(q)~='table' or type(q.group)~='string' or type(q.title)~='string' or
                type(q.symbol)~='string' or #q.symbol>100 or not manifest.titles[q.group..':'..norm(q.title)] then
                return nil,'Unapproved item quest.'
            end
            result.items[id][#result.items[id]+1]=q
        end
    end
    if itemCount<50 or itemCount>5000 then return nil,'Unexpected item coverage.' end
    for key,recipes in pairs(data.repeatTurnins) do
        if not manifest.ids[key] or type(recipes)~='table' or #recipes<1 or #recipes>50 then return nil,'Unapproved repeatable quest.' end
        for _,recipe in ipairs(recipes) do
            if type(recipe)~='table' or #recipe<1 or #recipe>20 then return nil,'Invalid turn-in recipe.' end
            local seen={}
            for _,item in ipairs(recipe) do
                if type(item)~='table' or not integer(item.id,1,65535) or item.id==4094 or
                    not integer(item.count,1,9999) or seen[item.id] then return nil,'Invalid turn-in item.' end
                seen[item.id]=true
            end
        end
        result.repeatTurnins[key]=recipes
    end
    return result
end
local function replace(target,value)
    for key in pairs(target) do target[key]=nil end
    for key,v in pairs(value) do target[key]=v end
end
function M.apply(data)
    -- All validation finishes before replacing any live index.
    local items=data.items
    for id,entries in pairs(require('data.legacy_item_quests')) do
        if id~=4094 then
            items[id]=items[id] or {}
            for _,q in ipairs(entries) do
                if manifest.titles[q.group..':'..norm(q.title)] then
                    local duplicate=false
                    for _,v in ipairs(items[id]) do if v.group==q.group and v.symbol==q.symbol then duplicate=true end end
                    if not duplicate then items[id][#items[id]+1]=q end
                end
            end
        end
    end
    replace(require('data.item_quests'),items)
    -- Retain verified legacy starters while the worker refreshes modern quest scripts.
    local npcs={}
    local seen={}
    for _,entries in ipairs({data.npcs,require('data.legacy_quest_npcs')}) do
        for _,q in ipairs(entries) do
            local approved=manifest.ids[q.group..':'..q.id]
            local key=q.zone..':'..norm(q.npc)..':'..q.group..':'..q.id
            if approved and approved.title==q.title and not seen[key] then
                seen[key]=true;npcs[#npcs+1]=q
            end
        end
    end
    replace(require('data.quest_npcs'),npcs)
    replace(require('data.repeat_turnins'),data.repeatTurnins)
    M.current={sha=data.sha,time=data.time,npcs=#npcs}
    M.revision=M.revision+1
end
function M.installCandidate(expectedSha)
    local candidate,body=read(M.path..'/cache/source-data-candidate.json')
    local data,err=M.validate(candidate)
    if not data then return false,err end
    if data.sha~=expectedSha then return false,'Source revision mismatch.' end
    local path=M.path..'/cache/source-data-current.json'
    local f,writeErr=io.open(path..'.tmp','wb');if not f then return false,writeErr end
    local wrote=f:write(body);local closed=f:close()
    if not wrote or not closed then return false,'Could not save updated data.' end
    local old=io.open(path,'rb')
    if old then
        old:close();os.remove(path..'.bak')
        local ok,e=os.rename(path,path..'.bak');if not ok then return false,e end
    end
    local ok,e=os.rename(path..'.tmp',path)
    if not ok then os.rename(path..'.bak',path);return false,e end
    M.apply(data)
    os.remove(M.path..'/cache/source-data-candidate.json')
    return true
end
return M
