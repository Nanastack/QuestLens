-- Lightweight screen projection inspired by the installed xonellines renderer.
-- Cached Moogle texture and solid question mark; no animation writes or depth draws.
local M={camera=nil,pass=0,lastScan=-100,candidates={},zone=nil,fault=nil}
local imgui=require('imgui')
local bit=require('bit')
local ok,d3d=pcall(require,'d3d8')
local ffi=require('ffi')
local references=require('data.quest_npcs')
local turnins=require('data.repeat_turnins')
local eligibility=require('data.quest_eligibility')
M.available=ok
local zones={}
local function norm(s)return (s or ''):lower():gsub('[^%w]','') end
function M.reloadData()
    zones={}
    for _,entry in ipairs(references) do
        zones[entry.zone]=zones[entry.zone] or {}
        local key=norm(entry.npc);zones[entry.zone][key]=zones[entry.zone][key] or {}
        table.insert(zones[entry.zone][key],entry)
    end
    if M.reset then M.reset() end
end
M.reloadData()
function M.drawMarker(drawList,x,y,factor,variant,static)
    factor=factor or 1
    if not static then x=x+64*factor end -- Keep world markers clear of the silhouette.
    -- One slow cycle every 2.5 seconds, three pixels either side of the anchor.
    if not static then y=y+math.sin((M.animationTime or 0)*2*math.pi/2.5)*3 end
    local texture=M.moogleTexture
    if texture then
        local width=48*factor*texture.w/texture.h
        local success,err=pcall(function()
            drawList:AddImage(texture.id,{x-width/2,y-24*factor},{x+width/2,y+24*factor},{0,0},{1,1},0xFFFFFFFF)
        end)
        M.imageError=not success and tostring(err) or nil
    end
    local function point(a,b)return {x+a*factor,y+b*factor} end
    if variant=='ready' then
        local green=0xFF55DD55
        drawList:AddQuadFilled(point(7,-24),point(10,-27),point(15,-22),point(12,-19),green)
        drawList:AddQuadFilled(point(12,-19),point(15,-22),point(25,-34),point(28,-31),green)
        return
    elseif variant=='repeat' then
        local color=0xFF44DDEE
        local function line(a,b,c,d)
            drawList:AddLine(point(a,b),point(c,d),color,math.max(1,3*factor))
        end
        local function corner(cx,cy,startAngle)
            for i=0,5 do
                local a=startAngle+i*math.pi/12
                local b=startAngle+(i+1)*math.pi/12
                line(cx+3*math.cos(a),cy+3*math.sin(a),cx+3*math.cos(b),cy+3*math.sin(b))
            end
        end
        -- Top arrow travels up the left side, then points right.
        line(5,-17,5,-30);corner(8,-30,math.pi)
        line(8,-33,16,-33)
        drawList:AddTriangleFilled(point(15,-38),point(21,-33),point(15,-28),color)
        -- Bottom arrow travels down the right side, then points left.
        line(23,-33,28,-33);corner(28,-30,-math.pi/2)
        line(31,-30,31,-17);corner(28,-17,0)
        line(28,-14,20,-14)
        drawList:AddTriangleFilled(point(21,-19),point(15,-14),point(21,-9),color)
        corner(8,-17,math.pi/2);line(8,-14,12,-14)
        return
    end
    -- Use the same filled-rectangle API as the working exclamation marker.
    -- Texture failure must not prevent the question mark from being drawn.
    local rectangles={{10,-35,20,-31},{7,-32,11,-27},{19,-32,23,-24},
        {15,-26,21,-22},{12,-23,17,-16},{12,-11,17,-6}}
    for _,r in ipairs(rectangles) do
        drawList:AddRectFilled({x+r[1]*factor,y+r[2]*factor},{x+r[3]*factor,y+r[4]*factor},0xFF44DDEE,1)
    end
end
function M.preview()
    local extended={M.extendedRange==true}
    if imgui.Checkbox('Extended test range (all loaded, on-screen NPCs)',extended) then
        M.extendedRange=extended[1];M.reset()
    end
    if M.extendedRange then
        imgui.TextColored({1,0.75,0.2,1},'EXTENDED TEST RANGE ACTIVE')
    end
    imgui.TextWrapped('Extended range removes the 5-yalm limit without bypassing quest checks. Only NPCs loaded by the game can be tested. Resets on addon reload.')
    local enabled={M.debugWorld==true}
    if imgui.Checkbox('Preview Moogle marker above player and visible NPCs',enabled) then
        M.debugWorld=enabled[1];M.fault=nil;M.reset()
    end
    imgui.TextWrapped('Enable this to place the real world marker above your character and on-screen NPCs within 5 yalms, regardless of quest status. You can close this window while testing. Disable the checkbox to stop; preview also turns off on addon reload.')
    if M.debugWorld then imgui.TextColored({1,0.75,0.2,1},'IN-WORLD DEBUG PREVIEW ACTIVE - quest checks bypassed') end
    imgui.TextWrapped('Completed repeatable quests: looping arrow means missing or unverified items; green check means the full verified recipe is in Inventory. Other conditions and cooldowns may still apply.')
    imgui.TextWrapped('Hidden during cutscenes and zoning. NPC waving is not implemented. Normal quest markers do not yet check fame or all acceptance requirements.')
    imgui.TextWrapped(M.available and 'D3D camera support: available' or 'D3D camera support: unavailable')
    imgui.TextWrapped('Markers drawn last frame: '..tostring(M.lastDrawn or 0))
    imgui.TextWrapped('Renderer status: '..(M.status or 'Waiting for preview'))
    if M.captureRejected then imgui.TextWrapped('UI camera ignored; retaining last valid world camera.') end
    if M.captureError then imgui.TextWrapped('Camera error: '..M.captureError) end
    imgui.TextWrapped(M.moogleTexture and 'Moogle texture: loaded' or 'Moogle texture: unavailable')
    if M.imageError then imgui.TextWrapped('Moogle image draw error: '..M.imageError) end
    if M.fault then imgui.TextWrapped('World renderer error: '..M.fault) end
    if imgui.Button('Retry world renderer') then M.fault=nil;M.imageError=nil;M.reset() end
    imgui.Separator()
    imgui.TextWrapped('NPC quest verification (normal or extended test range)')
    imgui.TextWrapped('Disable the preview above to test real quest markers. Real markers show indexed unaccepted quests and confirmed completed repeatable quests. Fame and other acceptance prerequisites remain unverified.')
    if not M.inspection or #M.inspection==0 then
        imgui.TextWrapped('No indexed quest NPCs found in the selected test range. Starter NPC coverage is incomplete.')
    else
        for _,line in ipairs(M.inspection) do imgui.TextWrapped(line) end
    end
end
function M.canShow(login,zoning,status,event,hidden)
    return login==2 and not zoning and status~=4 and not event and not hidden
end
function M.setInventory(items,known)
    M.owned={};M.inventoryKnown=known==true
    for _,item in ipairs(items) do M.owned[item.id]=(item.bags or {})[0] or 0 end
end
function M.variant(entry,state)
    if M.unaccepted(entry,state) then return 'quest' end
    local key=entry.group..':'..entry.id
    if (M.ignored or {})[key] or not (state.completedQuests[entry.group] or {})[entry.id] then return nil end
    local recipes=turnins[key]
    if not recipes and not (M.repeatable or {})[key] then return nil end
    if recipes and M.inventoryKnown then
        for _,recipe in ipairs(recipes) do
            local ready=true
            for _,item in ipairs(recipe) do
                if ((M.owned or {})[item.id] or 0)<item.count then ready=false;break end
            end
            if ready then return 'ready' end
        end
    end
    return 'repeat'
end
function M.unaccepted(entry,state)
    local gates=eligibility[entry.group..':'..entry.id] or entry
    for _,blocked in ipairs(gates.requiresNotActive or {}) do
        if (state.quests[blocked.group] or {})[blocked.id] then return false end
    end
    for _,previous in ipairs(gates.requiresCompleted or {}) do
        if not (state.completedQuests[previous.group] or {})[previous.id] then return false end
    end
    return not (M.ignored or {})[entry.group..':'..entry.id] and state.seen[entry.group] and state.completedQuests[entry.group]~=nil and
        not (state.quests[entry.group] or {})[entry.id] and not state.completedQuests[entry.group][entry.id]
end
-- Estimated head heights, not measured skeleton bounds.
local raceHeights={[1]=1.85,[2]=1.77,[3]=2.10,[4]=2.00,[5]=1.05,[6]=1.05,[7]=1.60,[8]=2.05}
function M.headHeight(race,scale)
    if not scale or scale~=scale or scale<=0 or scale>4 then scale=1 end
    return (raceHeights[race] or 2.15)*scale+((race==5 or race==6) and 0.85 or 0.25)
end
function M.distanceScale(depth)
    return math.max(0.42,math.min(1.33,8/math.max(depth,0.01)))
end
function M.renderPosition(pointer)
    -- Actor fields are X, vertical Z, horizontal Y in memory order.
    -- Match targetlines' getBone output followed by drawArc's Y/Z swap.
    return {x=ashita.memory.read_float(pointer+0x678),
        y=ashita.memory.read_float(pointer+0x67C),z=ashita.memory.read_float(pointer+0x680)}
end
function M.inRange(a,b)
    return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=25
end
local function transform(x,y,z,w,m)
    return x*m._11+y*m._21+z*m._31+w*m._41,
        x*m._12+y*m._22+z*m._32+w*m._42,
        x*m._13+y*m._23+z*m._33+w*m._43,
        x*m._14+y*m._24+z*m._34+w*m._44
end
function M.project(p,view,projection,vp)
    local x,y,z,w=transform(p.x,p.y,p.z,1,view)
    x,y,z,w=transform(x,y,z,w,projection)
    if w<=0.01 then return nil,nil,'Behind camera or inside near plane' end
    if z/w<0 or z/w>1 then return nil,nil,'Outside camera depth range' end
    local sx,sy=vp.X+(x/w+1)*vp.Width/2,vp.Y+(1-y/w)*vp.Height/2
    if sx<vp.X or sx>vp.X+vp.Width or sy<vp.Y or sy>vp.Y+vp.Height then return nil,nil,'Outside screen bounds' end
    return sx,sy,nil,M.distanceScale(w)
end
local function capture()
    local device=d3d.get_device();if not device then return end
    local a,view=device:GetTransform(ffi.C.D3DTS_VIEW)
    local b,projection=device:GetTransform(ffi.C.D3DTS_PROJECTION)
    local c,vp=device:GetViewport()
    if a~=0 or b~=0 or c~=0 then M.captureError='D3D transform or viewport read failed';return end
    -- UI passes use orthographic transforms. Never replace the cached world
    -- camera with those; their depth test makes every world marker disappear.
    if vp.Width<=0 or vp.Height<=0 or math.abs(tonumber(projection._34))<0.00001 then
        M.captureRejected=true;return
    end
    M.captureRejected=false;M.capturedThisFrame=true
    local function copy(m)
        local result={}
        for i=1,4 do for j=1,4 do local k='_'..i..j;result[k]=m[k] end end
        return result
    end
    M.camera={view=copy(view),projection=copy(projection),viewport={X=vp.X,Y=vp.Y,Width=vp.Width,Height=vp.Height}}
end
function M.beginScene(enabled)
    M.pass=M.pass+1
    if enabled and M.available and not M.fault and M.pass==2 then
        local success,err=pcall(capture)
        M.captureError=not success and tostring(err) or nil
    end
end
local eventPointer,hiddenPointer
if ashita and ashita.memory and ashita.memory.find then
    pcall(function()
        eventPointer=ashita.memory.find('FFXiMain.dll',0,'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3',0,0)
        hiddenPointer=ashita.memory.find('FFXiMain.dll',0,'8B4424046A016A0050B9????????E8????????F6D81BC040C3',0,0)
    end)
end
local function flag(pointer,offset,field)
    if not pointer or pointer==0 then return false end
    local address=ashita.memory.read_uint32(pointer+offset)
    return address~=0 and ashita.memory.read_uint8(address+(field or 0))==1
end
local function draw(state,time)
    local mm=AshitaCore:GetMemoryManager();local player=mm:GetPlayer();local party=mm:GetParty()
    local index=party:GetMemberTargetIndex(0);if not index or index==0 then M.status='Player entity unavailable';return end
    local entities=mm:GetEntity();local zoning=player:GetIsZoning()
    if not M.canShow(player:GetLoginStatus(),zoning==true or type(zoning)=='number' and zoning~=0,
        entities:GetStatus(index),flag(eventPointer,1),flag(hiddenPointer,10,0xB4)) then M.status='Hidden: login, zoning, cutscene or game interface';return end
    local zone=party:GetMemberZone(0);local starters=zones[zone]
    if not starters and not M.debugWorld then M.status='No indexed NPC quests in this zone';return end
    local me={x=entities:GetLocalPositionX(index),y=entities:GetLocalPositionZ(index),z=entities:GetLocalPositionY(index)}
    if M.zone~=zone or time-M.lastScan>=0.5 then
        M.candidates={};M.zone=zone;M.lastScan=time
        for id=0,0x8FF do
            local pointer=entities:GetActorPointer(id)
            if pointer and pointer~=0 then
                local flags=entities:GetSpawnFlags(id)
                if bit.band(flags,2)~=0 and bit.band(flags,0x11)==0 then
                    local quests=starters and starters[norm(entities:GetName(id))]
                    if M.debugWorld or quests then M.candidates[#M.candidates+1]={index=id,quests=quests or {}} end
                end
            end
        end
    end
    M.inspection={}
    local drawn=0;local camera=M.camera;local drawList=imgui.GetBackgroundDrawList()
    local function drawEntity(id,variant)
        local pointer=entities:GetActorPointer(id)
        if not pointer or pointer==0 then return end
        -- The actor's interpolated render position follows movement and mounts;
        -- entity LocalPosition is the logical position, not the rendered anchor.
        local p=M.renderPosition(pointer)
        if not M.extendedRange and not (M.debugWorld and id==index) and not M.inRange(p,me) then return end
        local scale=entities:GetModelSize(id);if not scale or scale<=0 or scale>4 then scale=1 end
        local race=entities.GetRace and entities:GetRace(id) or nil
        p.y=p.y-M.headHeight(race,scale)*(M.heightFactor or 0.65)
        local x,y,reason,factor=M.project(p,camera.view,camera.projection,camera.viewport)
        if id==index then M.playerProjection=reason or 'Player marker projected' end
        if x then
            if race==5 or race==6 then y=y-20*factor end
            M.drawMarker(drawList,x,y,factor,variant);drawn=drawn+1;M.lastDrawn=drawn
        end
    end
    M.status='Camera ready; player index '..tostring(index)
    if M.debugWorld then drawEntity(index);M.status=M.playerProjection or 'Player actor unavailable' end
    for _,npc in ipairs(M.candidates) do
        local id=npc.index
        local pointer=entities:GetActorPointer(id)
        if pointer and pointer~=0 and #npc.quests>0 then
            local position=M.renderPosition(pointer)
            if M.extendedRange or M.inRange(position,me) then
                local npcName=entities:GetName(id) or 'NPC'
                for _,quest in ipairs(npc.quests) do
                    local status
                    if (M.ignored or {})[quest.group..':'..quest.id] then status='Ignored - no quest marker'
                    elseif not state.seen[quest.group] or state.completedQuests[quest.group]==nil then status='Waiting for quest log data'
                    elseif (state.quests[quest.group] or {})[quest.id] then status='Active in tracker - no quest marker'
                    elseif state.completedQuests[quest.group][quest.id] then
                        local variant=M.variant(quest,state)
                        status=variant=='ready' and 'Repeatable - turn-in items in Inventory' or variant=='repeat' and 'Repeatable - items missing or requirements unverified' or 'Completed - no quest marker'
                    else status='Unaccepted - quest marker enabled (prerequisites unverified)' end
                    M.inspection[#M.inspection+1]=npcName..': '..quest.title..' - '..status
                end
            end
        end
        local variant=M.debugWorld and 'quest' or nil
        for _,quest in ipairs(npc.quests) do
            local candidate=M.variant(quest,state)
            if not M.debugWorld and candidate and (not variant or candidate=='ready' or candidate=='quest' and variant=='repeat') then variant=candidate end
        end
        local available=variant~=nil
        if available and (M.debugWorld or M.extendedRange or drawn<16) then
            drawEntity(npc.index,variant)
        end
    end
end
function M.present(state,time,enabled)
    M.animationTime=time
    M.lastDrawn=0
    if enabled and M.available and not M.fault then
        local success,err=pcall(capture)
        M.captureError=not success and tostring(err) or nil
    end
    if enabled and not M.camera then M.status='No world camera captured' end
    if enabled and M.available and M.camera and not M.fault then
        local success,err=pcall(draw,state,time)
        if not success then M.fault=tostring(err) end
    end
    M.pass=0;M.capturedThisFrame=false
end
function M.reset() M.inspection={};M.candidates={};M.zone=nil;M.camera=nil;M.pass=0;M.capturedThisFrame=false end
return M
