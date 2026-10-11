local ffi = require('ffi')
local json = require('json')
local titles=require('data.wiki_titles')
local localGuides=require('data.local_guides')
local sourceRevision=require('data.source_revision')
local sourceData=require('lib.source_data')
local siteTitles=require('lib.site_titles')
local M = {pages={},queue={},pending={},textures={}}
M.maxAge=24*60*60
M.fallbackAge=7*24*60*60
M.sourceStatus=nil;M.sourceActive=nil;M.sourceAttempt=0
M.retryAfter={}
M.background={};M.backgroundSeen={};M.backgroundPriority={};M.lastBackground=0
function M.resolve(title)
    if type(title)~='string' then return title end
    M.resolvedTitles=M.resolvedTitles or {}
    if M.resolvedTitles[title] then return M.resolvedTitles[title] end
    local normalized=title:lower():gsub('[^a-z0-9]','')
    for name in pairs(localGuides) do
        if name:lower():gsub('[^a-z0-9]','')==normalized then M.resolvedTitles[title]=name;return name end
    end
    local resolved=titles[normalized] or title
    M.resolvedTitles[title]=resolved;return resolved
end
function M.isKnown(title)
    return type(title)=='string' and (localGuides[M.resolve(title)]~=nil or titles[title:lower():gsub('[^a-z0-9]','')]~=nil)
end
local eraPages=setmetatable({},{__mode='k'})
function M.forPhoenix(page)
    if not page or not page.title then return page end
    if eraPages[page] then return eraPages[page] end
    local result={};for k,v in pairs(page) do result[k]=v end
    local wardrobe=require('lib.wardrobe')
    result.text,result.wardrobeNote=wardrobe.apply(page.title,page.text)
    result.preview=wardrobe.apply(page.title,page.preview)
    if not page.title:lower():find('gobbiebag',1,true) then eraPages[page]=result;return result end
    local lines={}
    for line in ((page.text or '')..'\n'):gmatch('(.-)\n') do
        if not line:lower():find('goblin stew',1,true) then lines[#lines+1]=line end
    end
    result.text=table.concat(lines,'\n');result.links={};result.images={}
    for _,v in ipairs(page.links or {}) do
        if not v.title:lower():find('goblin stew',1,true) then result.links[#result.links+1]=v end
    end
    for _,v in ipairs(page.images or {}) do
        if v.label~='4094.png' then result.images[#result.images+1]=v end
    end
    eraPages[page]=result;return result
end
pcall(ffi.cdef, 'intptr_t __stdcall ShellExecuteW(void*, const uint16_t*, const uint16_t*, const uint16_t*, const uint16_t*, int);')
pcall(ffi.cdef, 'int __stdcall MultiByteToWideChar(unsigned int, unsigned long, const char*, int, uint16_t*, int);')
local shell=ffi.load('shell32')
local kernel=ffi.load('kernel32')
local function wide(s)
    local n=kernel.MultiByteToWideChar(65001,0,s,#s,nil,0)
    local b=ffi.new('uint16_t[?]',n+1)
    kernel.MultiByteToWideChar(65001,0,s,#s,b,n);return b
end
function M.encode(s)
    return (s:gsub('[^%w%-_%.~]',function(c) return string.format('%%%02X',c:byte()) end))
end
local function key(s)
    local a,b=5381,7
    for i=1,#s do a=(a*33+s:byte(i))%4294967296;b=(b*65599+s:byte(i))%4294967296 end
    return string.format('%08x%08x',a,b)
end
function M.init(path)
    M.path=path:gsub('/','\\'):gsub('\\$','')
    sourceData.init(path)
    if sourceData.current then
        sourceRevision.sha=sourceData.current.sha
    end
    for _,page in pairs(localGuides) do
        if page.requirements and not page.requirementsRendered then
            for _,id in ipairs(page.requirements) do
                local name='Item #'..id
                local ok,item=pcall(function() return AshitaCore:GetResourceManager():GetItemById(id) end)
                if ok and item and item.Name and item.Name[1] then name=item.Name[1] end
                page.text=page.text..name..'\n\n'
                page.links[#page.links+1]={label=name,title=name}
            end
            page.text=page.text..(page.sourceText or '')
            page.requirementsRendered=true
        end
    end
end
local function read(title)
    local f=io.open(M.path..'\\cache\\'..key(title)..'.json','rb')
    if not f then return nil end
    local s=f:read('*a');f:close()
    local ok,v=pcall(json.decode,s)
    if ok and type(v)=='table' then return v end
end
function M.request(title,refresh)
    title=M.resolve(title)
    if type(title)~='string' or #title==0 or #title>200 then return end
    if not M.pages[title] then
        local v=read(title)
        if v and not v.error then M.pages[title]=v end
        if not M.pages[title] and localGuides[title] then
            M.pages[title]=localGuides[title]
            M.pages[title].wikiCheckedAt=v and v.time or 0
            M.pages[title].fallbackTried=v and not v.error and v.fallbackSchema==1 or false
        end
    end
    local page=M.pages[title]
    if page and page.source=='BG' and localGuides[title] then page.phoenixReference=localGuides[title] end
    if not refresh and page and page.localGuide and page.fallbackTried and os.time()-(page.wikiCheckedAt or 0)<(M.fallbackAge or 604800) then return page end
    local maxAge=page and page.source=='BG' and (M.fallbackAge or 604800) or M.maxAge
    local oldMaps=page and not page.mapSchema and (page.text or ''):find('Map %d')
    if not refresh and not oldMaps and page and not page.error and page.linkSchema==2 and
        os.time()-(page.time or 0)<maxAge then return page end
    if not refresh and os.time()<(M.retryAfter[title] or 0) then return page end
    if not M.pending[title] then
        M.pending[title]=true;M.queue[#M.queue+1]=title
    end
    return page
end
local function finish(title,v)
    local previous=M.pages[title]
    if v.source=='BG' and previous and not previous.error and not previous.localGuide and previous.source~='BG' then
        -- A transient Phoenix outage should keep its existing guide preferred.
        previous.refreshError='Phoenix unavailable; keeping its cached guide.'
        M.retryAfter[title]=os.time()+300
    elseif v.error then
        M.retryAfter[title]=os.time()+300
        if previous and not previous.error then
            previous.refreshError=v.error
            if previous.localGuide then
                previous.wikiCheckedAt=v.time or os.time()
                previous.fallbackTried=false
            end
        else M.pages[title]=v end
    else
        M.pages[title]=v;M.retryAfter[title]=nil
        if v.source=='BG' and localGuides[title] then v.phoenixReference=localGuides[title] end
        local prefix=key(title)..'-'
        for file,texture in pairs(M.textures) do
            if file:sub(1,#prefix)==prefix then
                if texture then texture.ptr.lpVtbl.Release(texture.ptr) end
                M.textures[file]=nil
            end
        end
    end
    M.pending[title]=nil;M.active=nil
end
-- Background requests never jump ahead of pages opened or hovered by the player.
function M.prefetch(title,priority)
    title=M.resolve(title)
    if type(title)~='string' or #title==0 or #title>200 then return end
    M.backgroundPriority=M.backgroundPriority or {}
    M.backgroundPriority[title]=math.max(M.backgroundPriority[title] or 0,priority or 0)
    if M.backgroundSeen[title] then return end
    local page=M.pages[title] or read(title)
    if localGuides[title] and (not page or page.error) then
        local checked=page and page.time or 0
        local tried=page and not page.error and page.fallbackSchema==1 or false
        page=localGuides[title];page.wikiCheckedAt=page.wikiCheckedAt or checked;M.pages[title]=page
        page.fallbackTried=page.fallbackTried or tried
    end
    if page and page.localGuide and page.fallbackTried and os.time()-(page.wikiCheckedAt or 0)<(M.fallbackAge or 604800) then return end
    if page and not page.error then
        M.pages[title]=page
        local maxAge=page.source=='BG' and (M.fallbackAge or 604800) or M.maxAge
        if page.linkSchema==2 and os.time()-(page.time or 0)<maxAge then return end
    end
    if M.pending[title] or os.time()<(M.retryAfter[title] or 0) then return end
    M.backgroundSeen[title]=true;M.background[#M.background+1]=title
end
function M.clearPrefetch()
    M.resolvedTitles={}
    M.background={};M.backgroundSeen={};M.backgroundPriority={}
end
local function readSource()
    local f=io.open(M.path..'\\cache\\source-status.json','rb')
    if not f then return end
    local body=f:read('*a');f:close()
    local ok,status=pcall(json.decode,body)
    if ok and type(status)=='table' then return status end
end
function M.updateDue(status,t)
    local interval=status and status.error and 86400 or 604800
    return not status or status.baseline~=sourceRevision.sha or t-(status.time or 0)>=interval
end
function M.checkUpdates(force)
    if M.sourceActive then return end
    if M.sourceStatus==nil then M.sourceStatus=readSource() end
    if not force and (not M.updateDue(M.sourceStatus,os.time()) or os.time()-M.sourceAttempt<86400) then return end
    M.sourceAttempt=os.time()
    os.remove(M.path..'\\cache\\source-status.json')
    local args='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'..
        M.path..'\\tools\\check_updates.ps1" -Baseline '..sourceRevision.sha
    if force then args=args..' -UpdateData' end
    local result=shell.ShellExecuteW(nil,wide('open'),wide('powershell.exe'),wide(args),nil,0)
    if tonumber(ffi.cast('intptr_t',result))<=32 then
        M.sourceStatus={error='Could not start the update checker.',time=os.time(),baseline=sourceRevision.sha}
    else M.sourceActive=os.time() end
end
function M.tickUpdates()
    if M.sourceActive then
        local status=readSource()
        if status and (status.time or 0)>=M.sourceActive then
            M.sourceStatus=status
            if status.running and os.time()-M.sourceActive>1800 then
                M.sourceStatus={error='Data update timed out.',time=os.time(),baseline=sourceRevision.sha}
                M.sourceActive=nil
            elseif not status.running then
                if status.dataReady and not status.error then
                    local ok,err=sourceData.installCandidate(status.sha)
                    if ok then
                        status.applied=true;sourceRevision.sha=status.sha
                        M.retryAfter={}
                        if M.onDataUpdated then M.onDataUpdated() end
                    else status.error='Update rejected: '..tostring(err) end
                end
                M.sourceActive=nil
            end
        elseif os.time()-M.sourceActive>1800 then
            M.sourceStatus={error='Update check timed out.',time=os.time(),baseline=sourceRevision.sha};M.sourceActive=nil
        end
    else M.checkUpdates(false) end
end
function M.updateMessage()
    if M.sourceActive then return M.sourceStatus and M.sourceStatus.message or 'Checking Phoenix source data...' end
    local status=M.sourceStatus
    if not status then return 'Quest-use index audited '..sourceRevision.audited..'.' end
    if status.error then return 'Data update failed; previous data retained. '..tostring(status.error) end
    if status.applied then return 'Quest data updated. NPC markers, item uses and repeatable recipes refreshed.' end
    if status.sha~=sourceRevision.sha then return 'Phoenix source has changed. The bundled quest-use index may need an addon update.' end
    return 'Phoenix source matches the bundled index. Checked '..os.date('%Y-%m-%d',status.time)..'.'
end
function M.tick()
    M.tickUpdates()
    if not M.active and #M.queue==0 and #M.background>0 and os.time()-M.lastBackground>=2 then
        local nextIndex=1
        for i=2,#M.background do
            if (M.backgroundPriority[M.background[i]] or 0)>(M.backgroundPriority[M.background[nextIndex]] or 0) then nextIndex=i end
        end
        local title=table.remove(M.background,nextIndex);M.backgroundSeen[title]=nil
        M.lastBackground=os.time();M.request(title)
    end
    if M.active then
        local v=read(M.active.title)
        if v and (v.error or (v.time or 0)>=M.active.started) then
            finish(M.active.title,v)
        elseif os.time()-M.active.started>130 then
            finish(M.active.title,{error='Wiki request timed out. Try Refresh again.'})
        end
    end
    if not M.active and #M.queue>0 then
        local title=table.remove(M.queue,1)
        -- Percent encoding prevents titles from becoming PowerShell syntax.
        local args='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'..
            M.path..'\\tools\\wiki.ps1" -Title "'..M.encode(siteTitles.resolve(title,'Phoenix'))..'" -Key '..key(title)
        if localGuides[title] then args=args..' -QuestReference' end
        args=args..' -BgTitle "'..M.encode(siteTitles.resolve(title,'BG'))..'"'
        -- Keep usable disk cache while refreshing; discard only an old error.
        local cached=read(title)
        if cached and cached.error then os.remove(M.path..'\\cache\\'..key(title)..'.json') end
        local result=shell.ShellExecuteW(nil,wide('open'),wide('powershell.exe'),wide(args),nil,0)
        if tonumber(ffi.cast('intptr_t',result))<=32 then
            finish(title,{error='Could not start the Windows wiki helper.'})
        else M.active={title=title,started=os.time()} end
    end
end
function M.url(title,site)
    title=M.resolve(title)
    title=siteTitles.resolve(title,site)
    local slug=M.encode(title:gsub(' ','_'))
    if site=='BG' then return 'https://www.bg-wiki.com/ffxi/'..slug end
    if site=='FFXIclopedia' then return 'https://ffxiclopedia.fandom.com/wiki/'..slug end
    return 'https://wiki.phoenix-xi.com/'..slug
end
local d3d,d3dx
do
    local ok,v=pcall(require,'d3d8')
    if ok then
        local ok2=pcall(require,'d3d8.d3dx8')
        -- Ashita exposes D3DX through the process namespace (as its own
        -- bundled addons do), not a separately installed d3dx8.dll.
        local ok3=pcall(function() return ffi.C.D3DXCreateTextureFromFileA end)
        if ok2 and ok3 then d3d=v;d3dx=ffi.C end
    end
end
function M.texture(file,asset)
    if not d3d or not file or not file:match('^[%w%-]+%.%w+$') then return nil end
    local textureKey=asset and ('asset:'..file) or file
    if M.textures[textureKey]~=nil then return M.textures[textureKey] or nil end
    local ok,value=pcall(function()
        local p=ffi.new('IDirect3DTexture8*[1]')
        local hr=d3dx.D3DXCreateTextureFromFileA(d3d.get_device(),M.path..(asset and '\\assets\\' or '\\cache\\')..file,p)
        if hr~=0 or p[0]==nil then return false end
        local desc=ffi.new('D3DSURFACE_DESC[1]')
        if p[0].lpVtbl.GetLevelDesc(p[0],0,desc)~=0 then
            p[0].lpVtbl.Release(p[0]);return false
        end
        return {ptr=p[0],id=tonumber(ffi.cast('uintptr_t',p[0])),w=tonumber(desc[0].Width),h=tonumber(desc[0].Height)}
    end)
    M.textures[textureKey]=ok and value or false;return M.textures[textureKey] or nil
end
local itemNames=require('data.item_names')
local itemIds={}
function M.itemId(title)
    if type(title)~='string' then return nil end
    local key=title:lower():gsub('[^a-z0-9]','')
    if itemIds[key]~=nil then return itemIds[key] or nil end
    local ok,item=pcall(function()return AshitaCore:GetResourceManager():GetItemByName(title,0)end)
    local id=ok and item and tonumber(item.Id) or itemNames[key]
    itemIds[key]=id or false
    return id
end
function M.itemIcon(id)
    local key='item:'..tostring(id)
    if M.textures[key] then return M.textures[key] end
    if not d3d then return nil end
    local ok,value=pcall(function()
        local item=AshitaCore:GetResourceManager():GetItemById(id)
        if not item or not item.Bitmap or not item.ImageSize or item.ImageSize<=0 then return nil end
        local p=ffi.new('IDirect3DTexture8*[1]')
        local hr=ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            d3d.get_device(),item.Bitmap,item.ImageSize,0xFFFFFFFF,0xFFFFFFFF,1,0,
            ffi.C.D3DFMT_A8R8G8B8,ffi.C.D3DPOOL_MANAGED,
            ffi.C.D3DX_DEFAULT,ffi.C.D3DX_DEFAULT,0xFF000000,nil,nil,p)
        if hr~=0 or p[0]==nil then return nil end
        return {ptr=p[0],id=tonumber(ffi.cast('uintptr_t',p[0])),w=32,h=32}
    end)
    if ok and value then M.textures[key]=value;return value end
end
function M.release()
    for _,v in pairs(M.textures) do if v then v.ptr.lpVtbl.Release(v.ptr) end end
    M.textures={}
end
return M
