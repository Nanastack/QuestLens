addon.name='questlens'
addon.author='Zarianna (100% vibe coded)'
addon.version='0.2.18'
addon.desc='Active quests and missions with Phoenix wiki hover cards and maps.'
require('common')
local imgui=require('imgui')
-- Ashita's newer ImGui uses integer child flags instead of bool borders.
local function beginChild(id,size,border,windowFlags)
    if ImGuiChildFlags_Borders~=nil then
        return imgui.BeginChild(id,size,border and ImGuiChildFlags_Borders or 0,windowFlags or 0)
    end
    return imgui.BeginChild(id,size,border,windowFlags or 0)
end
local tracker=require('lib.tracker')
local wiki=require('lib.wiki')
local catalog=require('data.catalog')
local inline=require('lib.inline')
local readable=require('lib.readable')
local inventory=require('lib.inventory')
local affiliation=require('lib.affiliation')
local pinStore=require('lib.pin_store')
local pinStatus=require('lib.pin_status')
local worldMarkers=require('lib.world_markers')
local itemQuests=require('data.item_quests')
for id,uses in pairs(require('data.legacy_item_quests')) do
    itemQuests[id]=itemQuests[id] or {}
    for _,entry in ipairs(uses) do
        local duplicate=false
        for _,known in ipairs(itemQuests[id]) do
            if known.group==entry.group and known.symbol==entry.symbol then duplicate=true;break end
        end
        if not duplicate then itemQuests[id][#itemQuests[id]+1]=entry end
    end
end
-- Phoenix era override: Goblin Stew 880 is not a valid Gobbiebag turn-in.
itemQuests[4094]=nil
-- Static server repositories can contain disabled/non-Phoenix content.
-- Only offer requirement matches with verified Phoenix wiki destinations.
for id,quests in pairs(itemQuests) do
    local verified={}
    for _,q in ipairs(quests) do
        if q.group~='CRYSTAL_WAR' and q.group~='WOTG' and q.group~='CAMPAIGN' and wiki.isKnown(q.title) then verified[#verified+1]=q end
    end
    itemQuests[id]=verified
end
local inventoryOpen={false}
local inventoryFilter={''}
local inventoryRows={}
local unavailableBags={}
local inventorySelected=nil
local inventoryBag=nil
local inventoryScanAt=-100
local inventoryKnown=false
local cacheScanAt=-100
wiki.init(addon.path)
worldMarkers.reloadData()
local state=tracker.new()
local opened={false}
local detail={false}
local search={''}
local lookup={''}
local linkedFilter={''}
local selected=nil
local history={}
local future={}
local kind='Quest'
local rows={}
local completedRows={}
local revision=-1
local pins={}
local trackingOptions={autoUnpin=true,showFollowup=false,worldMarkers=true,ignored={},markerHeight=0.65}
local missingNotices={}
local markerInventoryAt=-100
local completedNotice=nil
local ignoredNotice=nil
local reception={module=require('lib.quest_notices'),observer={groups={}},quests={},opened={false},at=0}
local hoverTitle,hoverStart
local lastPoll=0
local character=nil
local function inGame()
    local ok,status=pcall(function() return AshitaCore:GetMemoryManager():GetPlayer():GetLoginStatus() end)
    return ok and status==2
end
local socketOK,socket=pcall(require,'socket')
local now=function() return socketOK and socket.gettime() or os.time() end
local function say(s) print('\30\104[QuestLens] '..s..'\30\01') end
local function savePins()
    local ok,err=pinStore.save(addon.path,character,pins,trackingOptions)
    if not ok then say('Could not save tracking settings: '..tostring(err)) end
end
local function coverageNote()
    imgui.TextWrapped('Information is incomplete. Some Phoenix quests and item uses may be missing, and guides can change. No listed use does not mean an item has no quest use.')
end
local function coverageBanner()
    imgui.Spacing();imgui.Separator()
    imgui.TextColored({1,0.72,0.25,1},'NOTICE: QUEST AND GUIDE COVERAGE IS INCOMPLETE')
    imgui.TextWrapped('Some quests, item uses and guides are missing. See Information coverage / updates below.')
    imgui.Separator();imgui.Spacing()
end
local function updateControls()
    if imgui.Button('Check quest data updates') then wiki.checkUpdates(true) end
    imgui.TextWrapped(wiki.updateMessage())
    imgui.TextWrapped('Checks Phoenix source, downloads quest scripts and refreshes NPC markers, item uses and repeatable recipes. Previous data is retained if validation fails. Wiki guides refresh separately. New quest identities and unsupported script formats may still need an addon release.')
end
local refreshStatus='Waiting for incoming quest/mission data. Zoning can provide the game log.'
local function refreshLog()
    revision=-1;state.renderAfter=nil
    worldMarkers.reset()
    if state.revision>0 then
        refreshStatus='Display rebuilt from locally received quest/mission data.'
    else
        refreshStatus='No quest/mission data received yet. Local refresh cannot fetch it; try zoning.'
    end
    return true
end

local function go(title,push)
    title=wiki.resolve(title)
    if push and selected and selected~=title then
        history[#history+1]=selected;future={}
    end
    selected=title;detail[1]=true;linkedFilter[1]='';wiki.request(title)
end
local function navigateBack()
    if #history==0 then return end
    if selected then future[#future+1]=selected end
    go(table.remove(history),false)
end
local function navigateForward()
    if #future==0 then return end
    if selected then history[#history+1]=selected end
    go(table.remove(future),false)
end
local function mouseNavigation()
    if not detail[1] then return end
    if imgui.IsWindowHovered(ImGuiHoveredFlags_RootAndChildWindows or 3) then
        if imgui.IsMouseClicked(3) then navigateBack()
        elseif imgui.IsMouseClicked(4) then navigateForward() end
    end
end
local mapOpen={false}
local selectedImage=nil
local function image(v,maxw,maxh)
    local t=wiki.texture(v.file)
    if t then
        local scale=math.min(maxw/t.w,maxh/t.h,1)
        imgui.Image(t.id,{t.w*scale,t.h*scale})
        if imgui.IsItemClicked(0) then selectedImage=v;mapOpen[1]=true end
        return true
    end
end
local function showMap()
    if not mapOpen[1] or not selectedImage then return end
    imgui.SetNextWindowSize({650,720},ImGuiCond_FirstUseEver)
    if imgui.Begin('QuestLens - Map / Image',mapOpen) then
        imgui.TextColored({0.95,0.84,0.55,1},selectedImage.label or 'Map / Image')
        imgui.TextDisabled('Map supplied by the guide source; Phoenix details may differ.')
        beginChild('map-image',{0,0},true)
        local t=wiki.texture(selectedImage.file)
        if t then imgui.Image(t.id,{t.w,t.h}) else imgui.TextWrapped('Image unavailable. Refresh the guide to retry.') end
        imgui.EndChild()
    end
    imgui.End()
end
local function itemCard(page)
    local item=page.item
    if type(item)~='table' then return false end
    if (page.images or {})[1] and image(page.images[1],48,48) then imgui.SameLine() end
    imgui.TextColored({0.96,0.93,0.9,1},page.title or selected or '')
    if item.rare then imgui.TextColored({0.85,0.77,0.28,1},'RARE');imgui.SameLine() end
    if item.ex then imgui.TextColored({0.56,0.72,0.25,1},'EX') end
    local f=item.fields or {}
    imgui.TextDisabled(f.Type or '')
    imgui.Separator();imgui.TextWrapped(item.description or '')
    imgui.Separator()
    if f.Level or f.Slot then imgui.TextWrapped((f.Level and 'Lv. '..f.Level..'    ' or '')..(f.Slot or '')) end
    if f.Jobs then imgui.TextDisabled(f.Jobs) end
    imgui.Separator()
    if f['NPC sale price'] then imgui.TextDisabled('NPC value: '..f['NPC sale price'])
    elseif f['NPC value'] then imgui.TextDisabled('NPC value: '..f['NPC value']) end
    if f['Auction house'] then imgui.TextDisabled('Auction house: '..f['Auction house']) end
    return true
end
local function pinKey(entry)
    if entry.kind~='Quest' then return entry.key end
    local title=wiki.resolve(entry.name or entry.title or '')
    return 'Quest:'..entry.group..':'..title:lower():gsub('[^%w]','')
end
local function pinControl(entry)
    local key=pinKey(entry)
    local ignored=trackingOptions.ignored or {};trackingOptions.ignored=ignored
    local state=ignored[key] and 'ignored' or pins[key] and 'pinned' or 'neither'
    if state=='ignored' then
        local x,y=imgui.GetCursorScreenPos()
        local clicked=imgui.InvisibleButton('##restore',{20,20})
        local draw=imgui.GetWindowDrawList()
        if draw and type(x)=='number' and type(y)=='number' then
            local color=imgui.IsItemHovered() and 0xFF99FF99 or 0xFF55CC55
            draw:AddRectFilled({x+3,y+12},{x+15,y+15},color,1)
            draw:AddRectFilled({x+12,y+6},{x+15,y+15},color,1)
            draw:AddTriangleFilled({x+13.5,y+2},{x+8.5,y+8},{x+18.5,y+8},color)
        end
        if clicked then ignored[key]=nil;savePins() end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();imgui.TextUnformatted('Restore quest from Ignored');imgui.EndTooltip()
        end
        return
    end
    local changed=false
    if state=='neither' then
        local value={false}
        changed=imgui.Checkbox('##pin',value)
    else
        local x,y=imgui.GetCursorScreenPos()
        changed=imgui.InvisibleButton('##pin',{20,20})
        local draw=imgui.GetWindowDrawList()
        if draw and type(x)=='number' and type(y)=='number' then
            if state=='ignored' then
                local color=0xFF5555FF
                draw:AddCircle({x+10,y+10},7,color,24,2)
                local d=7/math.sqrt(2)
                draw:AddQuadFilled({x+10-d-0.7,y+10+d-0.7},{x+10+d-0.7,y+10-d-0.7},{x+10+d+0.7,y+10-d+0.7},{x+10-d+0.7,y+10+d+0.7},color)
            else
                local color=imgui.IsItemHovered() and 0xFF99EEFF or 0xFF55BBEE
                draw:AddRectFilled({x+6,y+2},{x+14,y+5},color,1)
                draw:AddRectFilled({x+8,y+5},{x+12,y+11},color,0)
                draw:AddLine({x+8,y+10},{x+4,y+13},color,2)
                draw:AddLine({x+12,y+10},{x+16,y+13},color,2)
                draw:AddLine({x+4,y+13},{x+16,y+13},color,2)
                draw:AddLine({x+10,y+13},{x+10,y+19},color,1.5)
            end
        end
    end
    if changed then
        if state=='neither' then pins[key]=entry;ignored[key]=nil
        else pins[key]=nil;ignored[key]=nil end
        savePins()
    end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.TextUnformatted(state=='ignored' and 'Ignored - click to clear' or state=='pinned' and
            'Pinned - click to unpin' or 'Click to pin')
        imgui.EndTooltip()
    end
    if entry.kind=='Quest' then
        imgui.SameLine()
        local x,y=imgui.GetCursorScreenPos()
        local clicked=imgui.InvisibleButton('##ignore',{20,20})
        local draw=imgui.GetWindowDrawList()
        if draw and type(x)=='number' and type(y)=='number' then
            local color=imgui.IsItemHovered() and 0xFF8888FF or 0xFF5555FF
            draw:AddCircle({x+10,y+10},7,color,24,2)
            local d=7/math.sqrt(2)
            draw:AddQuadFilled({x+10-d-0.7,y+10+d-0.7},{x+10+d-0.7,y+10-d-0.7},{x+10+d+0.7,y+10-d+0.7},{x+10-d+0.7,y+10+d+0.7},color)
        end
        if clicked then
            if ignored[key] then ignored[key]=nil
            else
                ignoredNotice={entry=entry,pinned=pins[key]}
                ignored[key]=entry;pins[key]=nil
            end
            savePins()
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();imgui.TextUnformatted(ignored[key] and 'Restore quest from Ignored' or 'Ignore quest: hide from normal tracking and NPC markers');imgui.EndTooltip()
        end
    end
end
local function affiliationIcons(entry)
    for _,icon in ipairs(affiliation.forEntry(entry)) do
        local texture=wiki.texture(icon.file,true)
        if texture then
            imgui.Image(texture.id,icon.wide and {64,24} or {24,24})
            if imgui.IsItemHovered() then
                imgui.BeginTooltip();imgui.PushTextWrapPos(320)
                imgui.TextWrapped(icon.label);imgui.PopTextWrapPos();imgui.EndTooltip()
            end
            imgui.SameLine()
        end
    end
end
local function tooltip(title)
    title=wiki.resolve(title)
    if not imgui.IsItemHovered() then return end
    if hoverTitle~=title then hoverTitle=title;hoverStart=now() end
    local page=wiki.forPhoenix(wiki.pages[title])
    if now()-hoverStart>0.2 then page=wiki.forPhoenix(wiki.request(title)) end
    imgui.BeginTooltip()
    imgui.PushTextWrapPos(390)
    imgui.TextColored({0.95,0.84,0.55,1},title)
    imgui.Separator()
    if page and not page.error then
        if page.source=='BG' then imgui.TextColored({1,0.78,0.35,1},'BG-WIKI: RETAIL GUIDE')
            imgui.TextWrapped('May not match Phoenix era. Fast travel, requirements and rewards can differ.');imgui.Separator() end
        if page.wardrobeNote then imgui.TextWrapped(page.wardrobeNote);imgui.Separator() end
        if not itemCard(page) then
            local pictures=page.images or {}
            if pictures[1] then image(pictures[1],160,100) end
            imgui.TextWrapped(page.preview or 'Click for details.')
        end
    elseif page and page.error then imgui.TextWrapped(page.error)
    else imgui.TextWrapped('Loading Phoenix wiki preview...') end
    imgui.Separator();imgui.TextDisabled('Click to open details')
    imgui.PopTextWrapPos();imgui.EndTooltip()
end
local ownership=require('lib.ownership')
local function greenCheck(label)
    imgui.SameLine()
    local x,y=imgui.GetCursorScreenPos()
    imgui.Dummy({16,18})
    if type(x)=='number' and type(y)=='number' then
        local draw=imgui.GetWindowDrawList()
        draw:AddLine({x+2,y+9},{x+6,y+13},0xFF66DD66,2.5)
        draw:AddLine({x+6,y+13},{x+14,y+3},0xFF66DD66,2.5)
    end
    if imgui.IsItemHovered() then imgui.BeginTooltip();imgui.TextUnformatted(label);imgui.EndTooltip() end
end
local guideLayout=require('lib.guide_layout')
local annotations=require('lib.guide_annotations')
local renderedPage,renderedBlocks
local function guideText(page)
    if renderedPage~=page then
        renderedPage=page;renderedBlocks=readable.blocks(page.text or '')
        for _,block in ipairs(renderedBlocks) do
            block.spans=inline.spans(block.text,page.links);local offset=1;block.annotationText=''
            for _,span in ipairs(block.spans) do span.annotationOffset=offset;offset=offset+#span.text;block.annotationText=block.annotationText..span.text end
        end
    end
    local width=math.max(80,math.min(780,imgui.GetContentRegionAvail()))
    local fontWidth,fontHeight=imgui.CalcTextSize('M')
    local fontKey=tostring(fontWidth)..':'..tostring(fontHeight)
    annotations.beginPage(page,renderedBlocks)
    local requirements,relatedItems=false,false
    for blockIndex,block in ipairs(renderedBlocks) do
        annotations.block(blockIndex,block.annotationText)
        local display=true
        if block.source then display=imgui.CollapsingHeader('Source and attribution') end
        if block.heading then
            relatedItems=block.text:lower():match('^related items')~=nil
            requirements=block.text:lower():match('^requirements')~=nil or block.text:lower():match('^required items')~=nil
            imgui.Spacing();imgui.Separator();imgui.Spacing()
            imgui.TextColored({0.95,0.84,0.55,1},block.text)
        elseif display then
        local used=0
        for _,span in ipairs(block.spans) do
        if span.title then
            local itemId=wiki.itemId(span.title)
            local icon=itemId and wiki.itemIcon(itemId)
            if icon then
                if used>0 and used+24<=width then imgui.SameLine(0,0) else used=0 end
                imgui.Image(icon.id,{18,18})
                if not annotations.enabled[1] and imgui.IsItemClicked(0) then go(span.title,true) end
                if not annotations.enabled[1] then tooltip(span.title) end
                used=used+22
            end
        end
        local runs,newUsed=guideLayout.runs(span,width,used,imgui.CalcTextSize,fontKey)
        for _,run in ipairs(runs) do
            if run.blankLines then
                for i=1,run.blankLines do imgui.NewLine() end
            else
                if run.sameLine then imgui.SameLine(0,0) end
                if span.title and not run.text:match('^%s+$') then
                    imgui.TextColored({0.95,0.75,0.4,1},run.text)
                    local map
                    for _,v in ipairs(page.images or {}) do
                        if span.title=='Map image: '..v.file then map=v;break end
                    end
                    if map then
                        if not annotations.enabled[1] and imgui.IsItemClicked(0) then selectedImage=map;mapOpen[1]=true end
                        if not annotations.enabled[1] and imgui.IsItemHovered() then
                            imgui.BeginTooltip();imgui.TextUnformatted(map.label or 'Map')
                            if not image(map,360,360) then imgui.TextWrapped('Image unavailable. Refresh guide to retry.') end
                            imgui.TextDisabled('Click to open the map inside QuestLens');imgui.EndTooltip()
                        end
                    else
                        if not annotations.enabled[1] and imgui.IsItemClicked(0) then go(span.title,true) end
                        if not annotations.enabled[1] then tooltip(span.title) end
                    end
                else imgui.TextUnformatted(run.text,#run.text) end
                annotations.run(block.annotationText,span.annotationOffset+(run.offset or 1)-1,run.text)
            end
        end
        used=newUsed
        end
        if relatedItems then
            local seen={}
            for _,span in ipairs(block.spans) do
                local id=span.title and wiki.itemId(span.title)
                if id and not seen[id] then
                    seen[id]=true
                    local owned=ownership.describe(span.title,inventoryRows,inventoryKnown,nil,inventory.bags)
                    if owned and owned.owned then
                        local verified=require('lib.item_requirements').verified(id,selected,itemQuests,wiki.resolve)
                        if verified then
                            greenCheck('Item owned; Phoenix scripts record a requirement for this quest. Verify the quantity and current step in the walkthrough.')
                            imgui.SameLine()
                            imgui.TextDisabled('('..owned.count..' owned; '..owned.allLocations..')')
                        else
                            imgui.SameLine()
                            imgui.TextDisabled('(Owned: '..owned.allLocations..')')
                        end
                    end
                end
            end
        end
        if requirements then
            local seen={}
            for _,span in ipairs(block.spans) do
                if span.title and not seen[span.title] then
                    seen[span.title]=true
                    local quantity=tonumber(block.text:match('^%s*(%d+)%s')) or tonumber(block.text:match('[xX]%s*(%d+)%s*$'))
                    local owned=ownership.describe(span.title,inventoryRows,inventoryKnown,quantity,inventory.bags)
                    if owned and owned.owned then
                        greenCheck(owned.quantityKnown and 'Required quantity owned' or 'Item owned; verify the quantity in the walkthrough')
                        if not owned.inventory then
                            imgui.SameLine();imgui.TextColored({0.8,0.9,0.8,1},'('..owned.locations..')')
                        elseif not owned.quantityKnown then
                            imgui.SameLine();imgui.TextDisabled('('..owned.count..' owned)')
                        end
                    end
                end
            end
        end
        if not block.field then imgui.Spacing() end
        end
    end
    annotations.endPage()
end
local function scanInventory()
    local ok,list,missing=pcall(function()
        return inventory.scan(AshitaCore:GetMemoryManager():GetInventory(),AshitaCore:GetResourceManager())
    end)
    if ok then inventoryRows=list;unavailableBags=missing;inventoryKnown=true else inventoryKnown=false;say('Inventory scan failed: '..tostring(list)) end
    inventoryScanAt=now()
end
wiki.onDataUpdated=function()
    worldMarkers.reloadData()
    inventoryScanAt=-100;cacheScanAt=-100;markerInventoryAt=-100
    wiki.clearPrefetch()
    for _,entry in ipairs(rows) do wiki.prefetch(entry.name,2) end
    if selected then wiki.request(selected,true) end
    say('Updated Phoenix quest data: NPC markers, item uses and repeatable turn-ins.')
end
local function showInventory()
    if not inventoryOpen[1] then return end
    if now()-inventoryScanAt>5 then scanInventory() end
    imgui.SetNextWindowSize({650,650},ImGuiCond_FirstUseEver)
    if imgui.Begin('QuestLens - Quest Items',inventoryOpen) then
        mouseNavigation()
        if imgui.Button('Rescan bags') then scanInventory() end
        imgui.SameLine();imgui.TextDisabled('Click an item to see quests that use it.')
        if imgui.CollapsingHeader('Information coverage / updates##inventory') then coverageNote();updateControls() end
        imgui.InputText('Find inventory item',inventoryFilter,128)
        if imgui.BeginTabBar('inventory-containers') then
            if imgui.BeginTabItem('All storage') then
                if inventoryBag~=nil then inventorySelected=nil end
                inventoryBag=nil;imgui.EndTabItem()
            end
            for _,bag in ipairs(inventory.tabOrder) do
                local label=bag==5 and 'Satchel' or inventory.bags[bag]
                if imgui.BeginTabItem(label..'##bag'..bag) then
                    if inventoryBag~=bag then inventorySelected=nil end
                    inventoryBag=bag;imgui.EndTabItem()
                end
            end
            imgui.EndTabBar()
        end
        imgui.TextDisabled(inventoryBag~=nil and inventory.bags[inventoryBag] or 'All storage')
        coverageBanner()
        beginChild('inventory-items',{0,220},true)
        local shown=0
        for _,v in ipairs(inventoryRows) do
            local n=#(itemQuests[v.id] or {})
            local quantity=inventory.quantity(v,inventoryBag)
            if n>0 and quantity>0 and v.name:lower():find(inventoryFilter[1]:lower(),1,true) then
                shown=shown+1
                local icon=wiki.itemIcon(v.id)
                if icon then
                    imgui.Image(icon.id,{20,20})
                    if imgui.IsItemClicked(0) then inventorySelected=v.id end
                    tooltip(v.name)
                else imgui.Dummy({20,20}) end
                imgui.SameLine()
                if imgui.Selectable(v.name..' x'..quantity..' ('..n..' quest uses)##inv'..v.id,inventorySelected==v.id) then
                    inventorySelected=v.id
                end
                tooltip(v.name)
            end
        end
        if shown==0 then imgui.TextWrapped('No known quest-use matches in this container. The index is incomplete; storage may also need to load.') end
        imgui.EndChild()
        beginChild('inventory-uses',{0,0},true)
        for _,v in ipairs(inventoryRows) do
            if v.id==inventorySelected and #(itemQuests[v.id] or {})>0 then
                imgui.TextColored({0.95,0.84,0.55,1},v.name..' - '..v.count..' owned')
                for bag=0,16 do
                    if v.bags[bag] then imgui.TextDisabled(inventory.bags[bag]..': '..v.bags[bag]) end
                end
                if imgui.Button('Item information') then go(v.name,true) end
                imgui.Spacing();imgui.Separator();imgui.Spacing()
                imgui.TextColored({0.95,0.84,0.55,1},'Quests that use this item:')
                imgui.Spacing()
                local matches=itemQuests[v.id] or {}
                for i,q in ipairs(matches) do
                    local active=false
                    local normalized=q.symbol:gsub('[^%w]',''):lower()
                    for _,r in ipairs(rows) do
                        if r.kind=='Quest' and r.group==q.group and r.name:gsub('[^%w]',''):lower()==normalized then active=true;break end
                    end
                    local entry={kind='Quest',group=q.group,symbol=q.symbol,title=q.title,name=wiki.resolve(q.title),sourceItems={{id=v.id,name=v.name}}}
                    for id,title in pairs(catalog.quests[q.group] or {}) do
                        if wiki.resolve(title)==entry.name then entry.id=id;break end
                    end
                    imgui.PushID('item-use-'..i)
                    pinControl(entry);imgui.SameLine()
                    affiliationIcons(entry)
                    local completed=tracker.isCompleted(state,entry)
                    local label=pinStatus.itemQuestLabel(entry,completed,active,wiki.pages[entry.name])
                    if imgui.Selectable(label..'##use'..i,false) then go(q.title,true) end
                    tooltip(q.title)
                    imgui.PopID()
                end
                if #matches==0 then imgui.TextWrapped('No use found in the current requirement index. This does not establish that the item has no quest use.') end
                imgui.TextDisabled('Click a quest to open its guide inside QuestLens.')
                break
            end
        end
        imgui.Separator()
        imgui.TextWrapped('Bag contents reflect data loaded by FFXI. Unloaded or unavailable bags are not counted. Active and Complete labels use the received quest log. Repeatable labels appear when verified by available guide metadata.')
        if #unavailableBags>0 then imgui.TextWrapped('Unavailable: '..table.concat(unavailableBags,', ')) end
        imgui.EndChild()
    end
    imgui.End()
end
local function entryForTitle(title)
    return require('lib.quest_identity').find(title,rows,pins,catalog,wiki.resolve,itemQuests,inventoryRows)
end
local function showDetails()
    if not detail[1] or not selected then return end
    if now()-inventoryScanAt>5 then scanInventory() end
    imgui.SetNextWindowSize({710,660},ImGuiCond_FirstUseEver)
    -- Plain text does not claim an active ImGui ID; prevent background drags
    -- from moving either the parent or its scrolling guide while selecting.
    local selectionFlags=annotations.enabled[1] and (ImGuiWindowFlags_NoMove or 4) or 0
    if imgui.Begin('QuestLens - Information',detail,selectionFlags) then
        mouseNavigation()
        if #history>0 then
            if imgui.Button('Back') then navigateBack() end
            imgui.SameLine()
        end
        if #future>0 then
            if imgui.Button('Forward') then navigateForward() end
            imgui.SameLine()
        end
        if imgui.Button('Refresh guide') then wiki.request(selected,true) end
        imgui.SameLine()
        if imgui.Button('Phoenix wiki') then ashita.misc.open_url(wiki.url(selected)) end
        imgui.SameLine()
        if imgui.Button('BG-Wiki') then ashita.misc.open_url(wiki.url(selected,'BG')) end
        imgui.SameLine()
        if imgui.Button('FFXIclopedia') then ashita.misc.open_url(wiki.url(selected,'FFXIclopedia')) end
        annotations.select(addon.path,character,wiki.resolve(selected))
        local page=wiki.forPhoenix(wiki.request(selected))
        local identity=require('lib.quest_identity')
        local entry=entryForTitle(selected) or (page and page.title and entryForTitle(page.title)) or identity.fromPage(selected,page)
        if entry then
            imgui.PushID('guide-pin');pinControl(entry)
            imgui.PopID();imgui.SameLine()
        elseif not page or not page.item then
            if imgui.Button('Pin as quest') then
                local manual=identity.unindexed(selected,page)
                pins[pinKey(manual)]=manual
                trackingOptions.ignored=trackingOptions.ignored or {};trackingOptions.ignored[pinKey(manual)]=nil
                revision=-1;savePins()
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip();imgui.TextWrapped('Track this page as a quest. Completion cannot be verified until it matches a known quest identity.');imgui.EndTooltip()
            end
            imgui.SameLine()
        end
        imgui.TextColored({0.95,0.84,0.55,1},selected)
        if entry and tracker.isCompleted(state,entry) then
            greenCheck('Completed')
        end
        if wiki.pending[selected] then imgui.TextDisabled('Checking Phoenix Wiki, then BG fallback...') end
        if page and page.time then imgui.TextDisabled((page.source=='BG' and 'BG-Wiki fetched: ' or 'Phoenix Wiki fetched: ')..os.date('%Y-%m-%d %H:%M',page.time)) end
        local rawPage=wiki.pages[selected]
        coverageBanner()
        if rawPage and rawPage.refreshError and not rawPage.localGuide then imgui.TextWrapped('Showing cached information; update failed: '..rawPage.refreshError) end
        if imgui.CollapsingHeader('Information coverage / updates##details') then coverageNote();updateControls() end
        if not page then
            imgui.TextWrapped('Loading wiki information in the background...')
        elseif page.error then
            imgui.TextWrapped(page.error)
            if imgui.Button('Search Phoenix wiki') then
                ashita.misc.open_url('https://wiki.phoenix-xi.com/index.php?search='..wiki.encode(selected))
            end
        else
            if page.source=='BG' then
                imgui.TextColored({1,0.78,0.35,1},'BG-Wiki fallback guide')
                imgui.TextWrapped('Phoenix guide unavailable or incomplete. BG-Wiki describes retail FFXI and may not match the Phoenix server era. Fast travel (such as Home Point warps), quest steps, requirements and rewards may be unavailable or different on Phoenix. Phoenix is checked again weekly, or when you click Refresh guide.')
                if page.phoenixReference and imgui.CollapsingHeader('Phoenix-verified item reference') then
                    guideText(page.phoenixReference)
                end
            end
            if page.title~=selected then imgui.TextDisabled('Wiki match: '..page.title) end
            if page.localGuide then
                imgui.TextColored({1,0.78,0.35,1},page.requirementReference and 'Phoenix script requirement reference' or 'Phoenix script guide')
                imgui.TextWrapped(page.requirementReference and 'Verified item references and NPC locations. A full walkthrough is not bundled for this quest.' or 'This quest has no indexed Phoenix Wiki page; information comes from its NPC script.')
            end
            if page.wardrobeNote then
                imgui.TextColored({1,0.78,0.35,1},'Wardrobe reward limit')
                imgui.TextWrapped(page.wardrobeNote)
                imgui.Separator()
            end
            if selected:lower():find('gobbiebag',1,true) then
                imgui.TextColored({1,0.78,0.35,1},'Phoenix: use the required materials. Goblin Stew is not an era-valid turn-in.')
            end
            if imgui.BeginTabBar('details-tabs') then
                if imgui.BeginTabItem('Guide / Stats') then
                    annotations.controls()
                    beginChild('guide',{0,-28},true,selectionFlags)
                    if itemCard(page) then imgui.Separator() end
                    guideText(page)
                    annotations.notes()
                    imgui.EndChild()
                    imgui.TextDisabled('Phoenix wiki text; use the full page for original layout.')
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem('Related items / zones') then
                    imgui.InputText('Filter links',linkedFilter,128)
                    imgui.TextDisabled('Hover for a preview; click to explore. Includes all article links.')
                    beginChild('links',{0,0},true)
                    local count=0
                    for i,v in ipairs(page.links or {}) do
                        if v.label:lower():find(linkedFilter[1]:lower(),1,true) then
                            count=count+1
                            if imgui.Selectable(v.label..'##link'..i,false) then go(v.title,true) end
                            tooltip(v.title)
                        end
                    end
                    if count==0 then imgui.TextWrapped('No matching links on this page.') end
                    imgui.EndChild();imgui.EndTabItem()
                end
                if imgui.BeginTabItem('Maps / Images') then
                    if imgui.Button('Open BG-Wiki maps') then ashita.misc.open_url(wiki.url(selected,'BG')..'#Maps') end
                    imgui.TextDisabled('Wiki images below; linked zone pages provide map coordinates and NPC information.')
                    beginChild('pictures',{0,0},true)
                    for i,v in ipairs(page.images or {}) do
                        imgui.PushID(i)
                        imgui.TextWrapped(v.label~='' and v.label or 'Wiki image')
                        if not image(v,640,600) then imgui.TextDisabled('Image preview unavailable.') end
                        if imgui.Button('Open original') then ashita.misc.open_url(v.url) end
                        imgui.Separator();imgui.PopID()
                    end
                    if #(page.images or {})==0 then imgui.TextWrapped('No supported images on this page. Open a linked zone or the full wiki page for maps.') end
                    imgui.EndChild();imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
        end
    end
    imgui.End()
end
ashita.events.register('packet_in','questlens_packets',function(e)
    if e.id==0x00A then
        worldMarkers.reset()
        inventoryRows={};inventorySelected=nil;inventoryScanAt=-100;inventoryKnown=false
        -- Refresh character data while keeping the current guide and navigation.
        state=tracker.new();rows={};completedRows={};revision=-1
        refreshStatus='Waiting for incoming quest/mission data after zoning.'
    elseif e.id==0x055 then
        state.keyItemCheckedAt=nil
        inventoryScanAt=-100;markerInventoryAt=-100
    elseif e.id==0x056 then
        if tracker.decode(state,e.data) then
            for _,entry in ipairs(reception.module.update(reception.observer,state,catalog)) do
                entry.name=wiki.resolve(entry.name)
                table.insert(reception.quests,1,entry)
                if #reception.quests>10 then table.remove(reception.quests) end
                reception.opened[1]=true;reception.at=now()
                wiki.prefetch(entry.name)
                print('\30\104[QuestLens] NEW QUEST: '..entry.name..' - /ql received to open the guide or pin it.\30\01')
            end
            refreshStatus='Quest/mission data received from the game.'
            state.renderAfter=now()+0.25
        end
    end
end)
ashita.events.register('command','questlens_command',function(e)
    local args=e.command:args()
    if #args==0 or (args[1]:lower()~='/ql' and args[1]:lower()~='/questlens') then return end
    e.blocked=true
    local cmd=(args[2] or 'toggle'):lower()
    if cmd=='show' then opened[1]=true
    elseif cmd=='received' then
        if #reception.quests>0 then reception.opened[1]=true;reception.at=now()
        else say('No newly accepted quests detected this session.') end
    elseif cmd=='inventory' then inventoryOpen[1]=not inventoryOpen[1];inventoryScanAt=-100
    elseif cmd=='reload' then AshitaCore:GetChatManager():QueueCommand(1,'/addon reload questlens')
    elseif cmd=='refresh' then refreshLog()
    elseif cmd=='updates' then wiki.checkUpdates(true);say(wiki.updateMessage())
    elseif cmd=='hide' then opened[1]=false;detail[1]=false;inventoryOpen[1]=false;reception.opened[1]=false
    elseif cmd=='toggle' then opened[1]=not opened[1]
    elseif cmd=='lookup' then
        local title=e.command:match('^%S+%s+%S+%s+(.+)$')
        if title then go(title:gsub('^"',''):gsub('"$',''),true) else say('Usage: /ql lookup Armada Sollerets') end
    elseif cmd=='help' then say('/ql show | hide | reload | refresh | updates | inventory | received | lookup <item, quest or zone> | help')
    else say('Unknown command. Use /ql help.') end
end)
ashita.events.register('d3d_present','questlens_draw',function()
    local t=now()
    if t-lastPoll>0.3 then wiki.tick();lastPoll=t end
    -- Character changes are handled in addition to zone-in resets.
    local party=AshitaCore:GetMemoryManager():GetParty()
    local name=party:GetMemberName(0)
    if not inGame() or not name or name=='' then
        name=nil
    end
    if name and name~='' and character~=name then
        worldMarkers.reset()
        if character then state=tracker.new();rows={};revision=-1;detail[1]=false;selected=nil;history={};future={} end
        ignoredNotice=nil;character=name;pins=pinStore.load(addon.path,name);trackingOptions=pinStore.loadOptions(addon.path,name)
        reception.observer=reception.module.new();reception.quests={};reception.opened[1]=false
        missingNotices={};completedNotice=nil
        inventoryRows={};inventorySelected=nil;inventoryScanAt=-100;cacheScanAt=-100;inventoryKnown=false
        wiki.clearPrefetch()
    end
    if name and t-(state.keyItemCheckedAt or -100)>=1 then
        local ok,owned=pcall(function() return AshitaCore:GetMemoryManager():GetPlayer():HasKeyItem(9) end)
        if ok and (type(owned)=='boolean' or type(owned)=='number') then tracker.setKeyItem(state,9,owned==true or type(owned)=='number' and owned~=0) end
        state.keyItemCheckedAt=t
    end
    if state.revision~=revision and (not state.renderAfter or t>=state.renderAfter) then
        rows=tracker.entries(state,catalog)
        for _,v in ipairs(rows) do v.name=wiki.resolve(v.name) end
        revision=state.revision;cacheScanAt=-100
        completedRows=tracker.completedEntries(state,catalog)
        for _,entry in ipairs(completedRows) do entry.name=wiki.resolve(entry.name) end
        local removed=false
        for key,entry in pairs(pins) do
            if not entry.id and entry.kind=='Quest' then
                for id,title in pairs(catalog.quests[entry.group] or {}) do
                    if wiki.resolve(title)==entry.name then entry.id=id;break end
                end
            end
            if trackingOptions.autoUnpin and tracker.isCompleted(state,entry) then
                pins[key]=nil;removed=true;completedNotice=entry
                say('QUEST/MISSION COMPLETED: '..entry.name..'. Removed its pin.')
                if trackingOptions.showFollowup then wiki.prefetch(entry.name) end
            end
        end
        if removed then savePins() end
    end
    if name and name~='' and t-cacheScanAt>30 then
        -- Scan every loaded container, regardless of the inventory panel or its filters.
        scanInventory()
        for _,entry in ipairs(rows) do wiki.prefetch(entry.name,2) end
        for _,item in ipairs(inventoryRows) do
            for _,quest in ipairs(itemQuests[item.id] or {}) do wiki.prefetch(quest.title,1) end
        end
        for _,item in ipairs(inventoryRows) do wiki.prefetch(item.name) end
        cacheScanAt=t
        for key,entry in pairs(pins) do
            local missing=tracker.isCompleted(state,entry) and {} or pinStatus.missingItems(entry,inventoryRows)
            if inventoryKnown and #missing>0 then
                if not missingNotices[key] then say(entry.name..': '..table.concat(missing,', ')..' not found in loaded storage.') end
                missingNotices[key]=true
            else missingNotices[key]=nil end
        end
    end
    if opened[1] then
        imgui.SetNextWindowSize({560,580},ImGuiCond_FirstUseEver)
        if imgui.Begin('QuestLens - Active Quests & Missions',opened) then
            mouseNavigation()
            imgui.TextDisabled(character or 'Waiting for character...')
            coverageBanner()
            if imgui.Button('Refresh display (local)') then refreshLog() end
            if refreshStatus~='' then imgui.TextWrapped(refreshStatus) end
            imgui.Dummy({0,8})
            local markersEnabled={trackingOptions.worldMarkers==true}
            if imgui.Checkbox('Quest markers',markersEnabled) then
                trackingOptions.worldMarkers=markersEnabled[1]
                worldMarkers.fault=nil;worldMarkers.reset();savePins()
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip();imgui.TextUnformatted('Show or hide NPC quest markers. Saved per character.');imgui.EndTooltip()
            end
            imgui.SameLine()
            local iconX,iconY=imgui.GetCursorScreenPos()
            imgui.Dummy({42,32})
            if type(iconX)=='number' and type(iconY)=='number' then
                worldMarkers.moogleTexture=wiki.texture('moogle.png',true)
                worldMarkers.drawMarker(imgui.GetWindowDrawList(),iconX+15,iconY+12,0.6,'quest',true)
            end
            imgui.Dummy({0,8})
            local bazaar=wiki.texture('bazaar.png',true)
            local questItemsClicked=false
            if imgui.Button('Quest Items') then questItemsClicked=true end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.PushTextWrapPos(320)
                imgui.TextWrapped('Find quests that use items in your inventory and storage.')
                imgui.PopTextWrapPos();imgui.EndTooltip()
            end
            if bazaar then
                imgui.SameLine()
                imgui.Image(bazaar.id,{24,24})
                if imgui.IsItemClicked(0) then questItemsClicked=true end
            end
            if questItemsClicked then inventoryOpen[1]=not inventoryOpen[1];inventoryScanAt=-100 end
            if imgui.CollapsingHeader('Information coverage / updates') then coverageNote();updateControls() end
            if imgui.CollapsingHeader('Tracking options') then
                local auto={trackingOptions.autoUnpin}
                local follow={trackingOptions.showFollowup}
                if imgui.Checkbox('Unpin completed quests / missions',auto) then trackingOptions.autoUnpin=auto[1];revision=-1;savePins() end
                if imgui.Checkbox('Show follow-up quests',follow) then trackingOptions.showFollowup=follow[1];savePins() end
                local height={trackingOptions.markerHeight or 0.65}
                if imgui.SliderFloat('Marker height',height,0.2,1.3,'%.2f') then trackingOptions.markerHeight=height[1];savePins() end
                imgui.TextWrapped('Lower values bring the Moogle closer to the NPC. Saved per character.')
                imgui.TextWrapped('Markers appear within 9 yalms for indexed quests you have not accepted or completed. Coverage is incomplete; fame, level and other prerequisites may still apply. Hidden during cutscenes and zoning.')
                if worldMarkers.fault then imgui.TextWrapped('Markers disabled after a rendering error: '..worldMarkers.fault) end
                imgui.TextWrapped('Follow-ups use the guide’s Next quest field when available. Item notices check loaded storage; unavailable bags may still hold the item.')
            end
            if ignoredNotice then
                imgui.TextWrapped('Quest ignored: '..ignoredNotice.entry.name)
                if imgui.SmallButton('Undo ignore') then
                    local key=pinKey(ignoredNotice.entry)
                    trackingOptions.ignored[key]=nil
                    if ignoredNotice.pinned then pins[key]=ignoredNotice.pinned end
                    ignoredNotice=nil;savePins()
                end
            end
            if imgui.BeginTabBar('questlens-main-tabs') then
            if imgui.BeginTabItem('Tracker') then
            if completedNotice then
                imgui.TextColored({0.5,0.9,0.55,1},'Completed: '..completedNotice.name)
                if trackingOptions.showFollowup then
                    local nextQuest=pinStatus.followup(wiki.request(completedNotice.name))
                    if nextQuest and imgui.SmallButton('Follow-up: '..nextQuest) then go(nextQuest,true) end
                end
            end
            imgui.InputText('Search active log',search,128)
            for _,v in ipairs({'Pinned','All','Quest','Mission','Unaccepted','Completed','Ignored'}) do
                if imgui.RadioButton(v,kind==v) then kind=v end
                imgui.SameLine()
            end
            imgui.NewLine();imgui.Separator()
            beginChild('active-log',{0,-110},true)
            local count=0
            local displayed=rows
            if kind=='Completed' then displayed=completedRows end
            local unaccepted={};local completed={}
            if kind=='Pinned' or kind=='Unaccepted' then
                displayed={};local seen={}
                for _,entry in ipairs(rows) do
                    local key=pinKey(entry)
                    seen[key]=true
                    if kind=='Pinned' and pins[key] then displayed[#displayed+1]=entry end
                end
                for key,entry in pairs(pins) do
                    if not seen[key] then
                        if tracker.isCompleted(state,entry) then
                            if kind=='Pinned' then displayed[#displayed+1]=entry;completed[key]=true end
                        elseif entry.kind=='Quest' then
                            displayed[#displayed+1]=entry;unaccepted[key]=true
                        elseif kind=='Pinned' then
                            displayed[#displayed+1]=entry
                        end
                    end
                end
                table.sort(displayed,function(a,b)return a.name<b.name end)
            end
            if kind=='Ignored' then
                displayed={}
                for _,entry in pairs(trackingOptions.ignored or {}) do
                    if type(entry)=='table' and entry.kind=='Quest' and type(entry.name)=='string' then displayed[#displayed+1]=entry end
                end
                table.sort(displayed,function(a,b)return a.name<b.name end)
            end
            for _,v in ipairs(displayed) do
                local filter=(v.name..' '..v.group):lower():find(search[1]:lower(),1,true)
                if filter and (kind=='Ignored' or not (trackingOptions.ignored or {})[pinKey(v)]) and (kind=='Ignored' or kind=='All' or kind=='Completed' or kind==v.kind or ((kind=='Pinned' or kind=='Unaccepted') and pins[pinKey(v)])) then
                    count=count+1;imgui.PushID(pinKey(v))
                    pinControl(v)
                    imgui.SameLine()
                    affiliationIcons(v)
                    local label=v.name..(unaccepted[pinKey(v)] and '  [Unaccepted]' or (v.completed or completed[pinKey(v)]) and '  [Completed]' or '')
                    if imgui.Selectable(label,false) then go((pins[pinKey(v)] or v).title or v.name,true) end
                    tooltip(v.name)
                    imgui.TextDisabled('    '..v.kind..' / '..v.group:gsub('_',' ')..(v.id and (' / '..v.id) or ' / Not in active log'))
                    if kind=='Completed' and v.kind=='Quest' then
                        local page=wiki.pages[v.name]
                        local repeatability=pinStatus.repeatability(page)
                        imgui.TextColored(repeatability=='Repeatable' and {0.5,0.9,0.55,1} or {0.85,0.85,0.85,1},'    '..repeatability)
                        if imgui.IsItemVisible() then wiki.prefetch(v.name) end
                    end
                    local pin=pins[pinKey(v)]
                    if pin then
                        if tracker.isCompleted(state,pin) then imgui.TextColored({0.5,0.9,0.55,1},'    Completed') end
                        local missing=tracker.isCompleted(state,pin) and {} or pinStatus.missingItems(pin,inventoryRows)
                        if inventoryKnown and #missing>0 then
                            imgui.TextColored({1,0.72,0.25,1},'    Item not found in loaded storage')
                            if imgui.IsItemHovered() then
                                imgui.BeginTooltip();imgui.PushTextWrapPos(340)
                                imgui.TextWrapped(table.concat(missing,', '))
                                if #unavailableBags>0 then imgui.TextWrapped('Some containers are unavailable; this does not confirm the item is gone from all storage.') end
                                imgui.PopTextWrapPos();imgui.EndTooltip()
                            end
                        end
                        if trackingOptions.showFollowup and v.kind=='Quest' then
                            local nextQuest=pinStatus.followup(wiki.request(v.name))
                            if nextQuest and imgui.SmallButton('Follow-up: '..nextQuest) then go(nextQuest,true) end
                        end
                    end
                    imgui.PopID()
                end
            end
            if count==0 then
                if kind=='Ignored' then imgui.TextWrapped('No ignored quests. Click the circle-and-slash button beside a quest to move it here.')
                elseif kind=='Completed' then imgui.TextWrapped('No matching completed entries received. Refresh the quest / mission log to update this list.')
                elseif kind=='Unaccepted' then imgui.TextWrapped('No matching pinned quests outside your active log. Pin a quest from Quest Items to add it here.')
                elseif kind=='Pinned' then imgui.TextWrapped('No matching pinned quests or missions.')
                else imgui.TextWrapped(next(state.seen) and 'No matching active entries.' or 'Waiting for incoming quest/mission packets. Zoning can provide the game log; Refresh display only rebuilds local data.') end
            end
            imgui.EndChild()
            imgui.TextDisabled(count..' shown. Box: pin/unpin. Circle/slash: ignore. Green arrow: restore.')
            imgui.InputText('Item / zone / wiki title',lookup,200)
            if imgui.Button('Look up information') and lookup[1]~='' then go(lookup[1],true) end
            imgui.TextDisabled('Hover entries for cards. Click entries for guides, links and maps.')
            imgui.EndTabItem()
            end
            if imgui.BeginTabItem('Debug') then
                imgui.TextWrapped('Real mode: unaccepted quests and completed repeatable quests show markers; ignored quests stay hidden. Debug preview bypasses those checks.')
                local realMarkers={trackingOptions.worldMarkers}
                if imgui.Checkbox('Enable real NPC quest markers',realMarkers) then
                    trackingOptions.worldMarkers=realMarkers[1];worldMarkers.reset();savePins()
                end
                local height={trackingOptions.markerHeight or 0.65}
                if imgui.SliderFloat('Marker height##debug',height,0.2,1.3,'%.2f') then trackingOptions.markerHeight=height[1];savePins() end
                worldMarkers.preview()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
            end
        end
        imgui.End()
    end
    if name and trackingOptions.worldMarkers and t-markerInventoryAt>=5 then
        scanInventory();markerInventoryAt=t
    end
    worldMarkers.heightFactor=trackingOptions.markerHeight or 0.65
    worldMarkers.setInventory(inventoryRows,inventoryKnown)
    worldMarkers.repeatable={}
    for _,entry in ipairs(completedRows) do
        if entry.kind=='Quest' and pinStatus.repeatability(wiki.pages[entry.name])=='Repeatable' then
            worldMarkers.repeatable[entry.group..':'..entry.id]=true
        end
    end
    worldMarkers.ignored={}
    for _,entry in pairs(trackingOptions.ignored or {}) do
        if type(entry)=='table' and entry.group and entry.id then worldMarkers.ignored[entry.group..':'..entry.id]=true end
    end
    if trackingOptions.worldMarkers or worldMarkers.debugWorld then worldMarkers.moogleTexture=wiki.texture('moogle.png',true) end
    worldMarkers.present(state,t,(trackingOptions.worldMarkers or worldMarkers.debugWorld) and name~=nil)
    showDetails()
    showInventory()
    showMap()
    if reception.opened[1] and name then
        if t-reception.at>=60 then reception.opened[1]=false
        else
            imgui.SetNextWindowSize({440,210},ImGuiCond_FirstUseEver)
            if imgui.Begin('QuestLens - Quests received',reception.opened) then
                imgui.TextDisabled('Newly accepted quests — closes after 60 seconds.')
                for i,entry in ipairs(reception.quests) do
                    imgui.PushID('received-'..i)
                    imgui.TextColored({0.95,0.84,0.55,1},entry.name)
                    if imgui.Button('Open guide') then go(entry.name,true) end
                    imgui.SameLine()
                    local key=pinKey(entry)
                    if imgui.Button(pins[key] and 'Unpin' or 'Pin') then
                        if pins[key] then pins[key]=nil else pins[key]=entry;trackingOptions.ignored[key]=nil end
                        savePins()
                    end
                    imgui.PopID()
                end
            end
            imgui.End()
        end
    end
end)
ashita.events.register('d3d_beginscene','questlens_marker_camera',function()
    worldMarkers.beginScene(trackingOptions.worldMarkers or worldMarkers.debugWorld)
end)
ashita.events.register('unload','questlens_unload',function() worldMarkers.cleanup();wiki.release() end)
