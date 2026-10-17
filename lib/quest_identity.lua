-- Resolve guide titles to real quest identities, respecting explicit nation suffixes.
local M={}
local nations={sandoria='SANDORIA',bastok='BASTOK',windurst='WINDURST',jeuno='JEUNO'}
local function norm(s)return (s or ''):lower():gsub('[^%w]','')end
local function split(title)
    local base,suffix=title:match('^(.-)%s*%(([^()]*)%)%s*$')
    local nation=suffix and nations[norm(suffix)]
    if nation then return base,nation end
    return title,nil
end
function M.find(title,rows,pins,catalog,resolve,itemQuests,inventoryRows)
    local base,nation=split(title)
    local target=norm(base)
    local function matches(name,group)
        if nation and group~=nation then return false end
        local resolved=split(resolve(name))
        return norm(resolved)==target
    end
    local function result(entry)
        local copy={};for k,v in pairs(entry)do copy[k]=v end
        if nation then copy.title=title end
        return copy
    end
    for _,entry in ipairs(rows)do if matches(entry.name,entry.group)then return result(entry)end end
    for _,entry in pairs(pins)do if matches(entry.name,entry.group)then return result(entry)end end
    local allowed={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,OTHER_AREAS=true,OUTLANDS=true,AHT_URHGAN=true,ZILART=true,COP=true,TOAU=true,ASSAULT=true}
    for _,kind in ipairs({'Quest','Mission'})do
        for group,names in pairs(catalog[kind=='Quest' and 'quests' or 'missions'])do
            if allowed[group]then
                for id,name in pairs(names)do
                    if matches(name,group)then return result({kind=kind,group=group,id=id,name=resolve(name),key=kind..':'..group..':'..id})end
                end
            end
        end
    end
    local itemEntry;local seenItems={}
    for id,uses in pairs(itemQuests)do
        for _,quest in ipairs(uses)do
            if allowed[quest.group] and matches(quest.title,quest.group)then
                itemEntry=itemEntry or {kind='Quest',group=quest.group,symbol=quest.symbol,title=quest.title,name=resolve(quest.title),sourceItems={}}
                if not seenItems[id]then
                    for _,owned in ipairs(inventoryRows)do
                        if owned.id==id and owned.count>0 then
                            itemEntry.sourceItems[#itemEntry.sourceItems+1]={id=id,name=owned.name};seenItems[id]=true;break
                        end
                    end
                end
            end
        end
    end
    return itemEntry and result(itemEntry) or nil
end
-- Unknown quests may be pinned without inventing a game-log ID.
function M.unindexed(title,page)
    local base,nation=split(title)
    local intro=(page and page.text or ''):sub(1,1200):lower()
    local group=nation
    if not group then
        if intro:find("san d'oria quest",1,true) or intro:find('sandoria quest',1,true) then group='SANDORIA'
        elseif intro:find('bastok quest',1,true) then group='BASTOK'
        elseif intro:find('windurst quest',1,true) then group='WINDURST'
        elseif intro:find('jeuno quest',1,true) then group='JEUNO' end
    end
    return {kind='Quest',group=group or 'OTHER_AREAS',name=title,title=title,known=false,sourceItems={}}
end
function M.fromPage(title,page)
    if not page or page.error or page.item then return nil end
    local text=(page.text or ''):lower()
    local quest=page.kind=='Quest' or text:sub(1,400):match('quest%s*\n') or
        (text:find('starting npc',1,true) and text:find('required fame',1,true) and text:find('repeatable',1,true))
    if quest then return M.unindexed(title,page) end
end
return M
