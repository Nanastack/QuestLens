-- Debug-only motion preview. Injected into the local incoming client stream;
-- never queues chat commands, outgoing packets, or game-server requests.
local M={enabled=true,delay=20,last= -100,actors={},facing={},pending={},status='Waiting for an eligible nearby NPC'}
function M.reset() M.tick(math.huge,true);M.requested=false;M.last=-100;M.actors={};M.status=M.enabled and 'Waiting for an eligible nearby NPC' or 'Disabled' end
local function angleDifference(a,b) return math.abs((a-b+math.pi)%(2*math.pi)-math.pi) end
function M.tick(time,cleanup)
    if cleanup then M.pending={} end
    if not next(M.facing) and not next(M.pending) then return end
    local ok=pcall(function()
        local mm=AshitaCore:GetMemoryManager();local player=mm:GetPlayer();local entities=mm:GetEntity()
        local zoning=player:GetIsZoning()
        local playerIndex=mm:GetParty():GetMemberTargetIndex(0)
        if player:GetLoginStatus()~=2 or zoning==true or type(zoning)=='number' and zoning~=0 or entities:GetStatus(playerIndex)==4 then M.facing={};M.pending={};return end
        for id,queued in pairs(M.pending) do
            if time>=queued.playAt then
                M.pending[id]=nil
                local valid=entities:GetServerId(id)==queued.actor and entities:GetActorPointer(id)==queued.pointer and entities:GetStatus(id)==0
                    and playerIndex==queued.player and entities:GetServerId(playerIndex)==queued.target
                if valid and not queued.renderRange then
                    local dx=entities:GetLocalPositionX(id)-entities:GetLocalPositionX(playerIndex)
                    local dy=entities:GetLocalPositionY(id)-entities:GetLocalPositionY(playerIndex)
                    local dz=entities:GetLocalPositionZ(id)-entities:GetLocalPositionZ(playerIndex)
                    valid=dx*dx+dy*dy+dz*dz<=144
                end
                if valid then
                    local sent,err=pcall(function() AshitaCore:GetPacketManager():AddIncomingPacket(0x05A,queued.packet) end)
                    M.status=sent and ('Local '..queued.name..' preview: '..(entities:GetName(id) or 'NPC')) or ('Local preview failed: '..tostring(err))
                    if M.facing[id] then M.facing[id].untilTime=time+6 end
                else
                    M.status='Greeting cancelled: NPC/player changed, unavailable or outside 12 yalms'
                    if M.facing[id] then M.facing[id].untilTime=time end
                end
            end
        end
        for id,snapshot in pairs(M.facing) do
            if time>=snapshot.untilTime then
                if entities:GetServerId(id)==snapshot.actor and entities:GetActorPointer(id)==snapshot.pointer and entities:GetStatus(id)==0 then
                    -- Restore only fields still holding our temporary direction.
                    if angleDifference(entities:GetLocalPositionYaw(id),snapshot.yaw)<0.03 then entities:SetLocalPositionYaw(id,snapshot.localYaw) end
                    if snapshot.lastYaw and angleDifference(entities:GetLastPositionYaw(id),snapshot.yaw)<0.03 then entities:SetLastPositionYaw(id,snapshot.lastYaw) end
                end
                M.facing[id]=nil
            end
        end
    end)
    if not ok then M.facing={};M.pending={} end
end
local function facePlayer(entities,npc,player,actor,time)
    if not entities.GetLocalPositionYaw or not entities.SetLocalPositionYaw then return end
    local dx=entities:GetLocalPositionX(player)-entities:GetLocalPositionX(npc)
    local dy=entities:GetLocalPositionY(player)-entities:GetLocalPositionY(npc)
    if dx*dx+dy*dy<0.001 then return end
    local yaw=-math.atan2(dy,dx)
    local previous=M.facing[npc]
    local snapshot={actor=actor,pointer=entities:GetActorPointer(npc),localYaw=entities:GetLocalPositionYaw(npc),yaw=yaw,untilTime=time+6.3}
    if entities.GetLastPositionYaw and entities.SetLastPositionYaw then snapshot.lastYaw=entities:GetLastPositionYaw(npc) end
    if previous and previous.actor==actor and previous.pointer==snapshot.pointer then
        if angleDifference(snapshot.localYaw,previous.yaw)<0.03 then snapshot.localYaw=previous.localYaw end
        if snapshot.lastYaw and angleDifference(snapshot.lastYaw,previous.yaw)<0.03 then snapshot.lastYaw=previous.lastYaw end
    end
    M.facing[npc]=snapshot
    entities:SetLocalPositionYaw(npc,yaw)
    if snapshot.lastYaw then entities:SetLastPositionYaw(npc,yaw) end
end
function M.tryWave(entities,npc,player,time,inRange,force,renderRange)
    local delay=math.max(5,math.min(300,tonumber(M.delay) or 20))
    if not inRange or (not force and (not M.enabled or time-M.last<delay)) then return false end
    local race=entities:GetRace(npc)
    if not race or race<1 or race>8 or entities:GetStatus(npc)~=0 then return false end
    local actor=entities:GetServerId(npc);local target=entities:GetServerId(player)
    if not actor or actor==0 or not target or target==0 or actor==target then return false end
    if not force and time-(M.actors[actor] or -100)<delay then return false end
    if M.pending[npc] or M.facing[npc] then return false end -- never restart an active greeting
    local packet={};for i=1,56 do packet[i]=0 end
    packet[1]=0x5A;packet[2]=28
    local function put(offset,value,size)
        for i=1,size do packet[offset+i]=value%256;value=math.floor(value/256) end
    end
    put(4,actor,4);put(8,target,4);put(12,npc,2);put(14,player,2)
    local choices={8,10,37} -- wave, welcome, huh
    local emote=choices[math.random(#choices)]
    put(16,emote,2);packet[23]=2 -- motion only; no emote chat message
    local ok,err=pcall(facePlayer,entities,npc,player,actor,time)
    if not ok then M.status='Could not prepare local facing: '..tostring(err);return false end
    local name=emote==8 and 'wave' or emote==10 and 'welcome' or 'huh'
    M.pending[npc]={actor=actor,pointer=entities:GetActorPointer(npc),player=player,target=target,packet=packet,name=name,playAt=time+0.3,renderRange=renderRange==true}
    M.last=time;M.actors[actor]=time
    M.status='Turning '..(entities:GetName(npc) or 'NPC')..' before '..name
    return true
end
return M
