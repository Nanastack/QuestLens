-- Passive decoder. All offsets include the four-byte FFXI packet header.
local M = {}
local areas = {'SANDORIA','BASTOK','WINDURST','JEUNO','OTHER_AREAS','OUTLANDS',
    'AHT_URHGAN','CRYSTAL_WAR','ABYSSEA','ADOULIN','COALITION'}
local ports = {0x50,0x58,0x60,0x68,0x70,0x78,0x80,0x88,0xE0,0xF0,0x100}
local allowedQuests={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,
    OTHER_AREAS=true,OUTLANDS=true,AHT_URHGAN=true}
local allowedMissions={SANDORIA=true,BASTOK=true,WINDURST=true,ZILART=true,
    COP=true,TOAU=true,ASSAULT=true}
local function u16(s,o) local a,b=s:byte(o+1,o+2); return a+b*256 end
local function u32(s,o) return u16(s,o)+u16(s,o+2)*65536 end
local function bits(s,start,count)
    local r={}
    for id=0,count-1 do
        local b=s:byte(start+math.floor(id/8)+1)
        if math.floor(b/2^(id%8))%2==1 then r[id]=true end
    end
    return r
end
function M.new() return {quests={},missions={},completedQuests={},completedMissions={},keyItems={},seen={},revision=0} end
local function mission(state,group,id,none,extra)
    state.missions[group]=nil
    if id~=none then state.missions[group]={id=id,extra=extra} end
end
function M.decode(state,s)
    if type(s)~='string' or #s<40 then return false end
    local port=u16(s,0x24)
    if port>=0x90 and port<=0xC8 and (port-0x90)%8==0 then
        local n=(port-0x90)/8+1
        state.completedQuests[areas[n]]=bits(s,4,n==7 and 128 or 256)
        if n==7 then state.completedMissions.ASSAULT=bits(s,20,128) end
        state.revision=state.revision+1;return true
    elseif port==0xD0 then
        for n,group in ipairs({'SANDORIA','BASTOK','WINDURST','ZILART'}) do
            state.completedMissions[group]=bits(s,4+(n-1)*8,64)
        end
        state.revision=state.revision+1;return true
    elseif port==0xD8 then
        state.completedMissions.TOAU=bits(s,4,64)
        state.revision=state.revision+1;return true
    end
    for n,p in ipairs(ports) do
        if port==p then
            -- Aht Urhgan has 128 quest bits; the rest is current mission data.
            state.quests[areas[n]]=bits(s,4,n==7 and 128 or 256)
            state.seen[areas[n]]=true
            if n==7 then
                mission(state,'TOAU',u32(s,0x18),0xFFFF)
                mission(state,'WOTG',u32(s,0x1C),0xFFFF)
                mission(state,'ASSAULT',u32(s,0x14),0)
                mission(state,'CAMPAIGN',u32(s,0x20),0)
            end
            state.revision=state.revision+1; return true
        end
    end
    if port==0xFFFF then
        for _,g in ipairs({'SANDORIA','BASTOK','WINDURST'}) do state.missions[g]=nil end
        local nation=({'SANDORIA','BASTOK','WINDURST'})[u32(s,4)+1]
        if nation then mission(state,nation,u16(s,8),0xFFFF) end
        mission(state,'ZILART',u16(s,12),0xFFFF)
        mission(state,'COP',u32(s,16),0,u32(s,20))
        local packed=u16(s,24)
        mission(state,'ACP',packed%16,0)
        mission(state,'AMK',math.floor(packed/16)%16,0)
        mission(state,'ASA',math.floor(packed/256)%16,0)
        local soa,rov=u32(s,28),u32(s,32)
        state.missions.SOA=nil;state.missions.ROV=nil
        if soa~=0 and soa~=999 and soa>=110 then mission(state,'SOA',math.floor((soa-110)/2),-1) end
        if rov~=0 and rov~=999 and rov>=108 then mission(state,'ROV',rov-108,-1) end
        state.seen.main=true
    elseif port==0xFFFE then
        local raw=u32(s,4)
        state.missions.TVR=nil
        if raw<2147483648 and raw~=0 and raw~=999 then
            local id=raw%65536
            if math.floor(id/4096)%2==1 then id=id-4096 end
            mission(state,'TVR',id,-1)
        end
        state.seen.TVR=true
    else return false end
    state.revision=state.revision+1;return true
end
function M.setKeyItem(state,id,owned)
    state.keyItems=state.keyItems or {}
    if state.keyItems[id]~=owned then state.keyItems[id]=owned;state.revision=state.revision+1 end
end
function M.isCompleted(state,entry)
    local title=(entry.name or entry.title or ''):lower():gsub('[^a-z0-9]','')
    if entry.kind=='Quest' and entry.group=='JEUNO' and (entry.symbol=='kazhamairshippass' or title=='kazhamairshippass') then
        return state.keyItems and state.keyItems[9]==true or false
    end
    if not entry.id then return false end
    local completed=entry.kind=='Quest' and state.completedQuests or state.completedMissions
    if completed and completed[entry.group] and completed[entry.group][entry.id] then return true end
    if entry.kind=='Mission' and entry.group=='COP' then
        local current=state.missions.COP
        return current~=nil and current.id>entry.id
    end
    return false
end
function M.entries(state,catalog)
    local r={}
    local function add(kind,group,id,extra)
        if not (kind=='Quest' and allowedQuests[group] or kind=='Mission' and allowedMissions[group]) then return end
        local names=catalog[kind=='Quest' and 'quests' or 'missions'][group] or {}
        r[#r+1]={kind=kind,group=group,id=id,name=names[id] or (group..' #'..id),
            known=names[id]~=nil,key=kind..':'..group..':'..id,extra=extra}
    end
    for group,ids in pairs(state.quests) do for id in pairs(ids) do add('Quest',group,id) end end
    for group,v in pairs(state.missions) do add('Mission',group,v.id,v.extra) end
    table.sort(r,function(a,b)
        if a.kind~=b.kind then return a.kind<b.kind end
        if a.group~=b.group then return a.group<b.group end
        return a.name<b.name
    end)
    return r
end
function M.completedEntries(state,catalog)
    local result={}
    local function add(kind,group,id)
        if not (kind=='Quest' and allowedQuests[group] or kind=='Mission' and allowedMissions[group]) then return end
        local names=catalog[kind=='Quest' and 'quests' or 'missions'][group] or {}
        if not names[id] then return end
        result[#result+1]={kind=kind,group=group,id=id,name=names[id],known=true,
            key=kind..':'..group..':'..id,completed=true}
    end
    for group,ids in pairs(state.completedQuests or {}) do
        for id in pairs(ids) do add('Quest',group,id) end
    end
    for group,ids in pairs(state.completedMissions or {}) do
        for id in pairs(ids) do add('Mission',group,id) end
    end
    local cop=state.missions.COP
    if cop then
        for id in pairs(catalog.missions.COP or {}) do
            if id>0 and id<cop.id then add('Mission','COP',id) end
        end
    end
    if state.keyItems and state.keyItems[9] then
        result[#result+1]={kind='Quest',group='JEUNO',name='Kazham Airship Pass',symbol='kazhamairshippass',completed=true,known=true}
    end
    table.sort(result,function(a,b)
        if a.kind~=b.kind then return a.kind<b.kind end
        if a.group~=b.group then return a.group<b.group end
        return a.name<b.name
    end)
    return result
end
return M
