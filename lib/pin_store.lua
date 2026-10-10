local M={}
local allowed={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,OTHER_AREAS=true,
    OUTLANDS=true,AHT_URHGAN=true,ZILART=true,COP=true,TOAU=true,ASSAULT=true}
local function filename(root,character)
    if type(character)~='string' or not character:match('^[%w%-]+$') then return nil end
    return root..'/settings/pins-'..character:lower()..'.json'
end
local function read(path)
    local f=io.open(path,'rb');if not f then return nil end
    local body=f:read('*a');f:close()
    local ok,data=pcall(require('json').decode,body)
    if ok and type(data)=='table' and data.version==1 and type(data.pins)=='table' then return data end
end
function M.load(root,character)
    local path=filename(root,character);if not path then return {} end
    local data=read(path) or read(path..'.bak') or {};local pins={}
    for key,entry in pairs(data.pins or {}) do
        if type(key)=='string' and type(entry)=='table' and allowed[entry.group] and
            (entry.kind=='Quest' or entry.kind=='Mission') and type(entry.name)=='string' then
            pins[key]=entry
        end
    end
    return pins
end
function M.loadOptions(root,character)
    local path=filename(root,character)
    local data=path and (read(path) or read(path..'.bak')) or {}
    local options=data and type(data.options)=='table' and data.options or {}
    return {autoUnpin=options.autoUnpin~=false,showFollowup=options.showFollowup==true,worldMarkers=options.worldMarkers~=false,ignored=type(options.ignored)=='table' and options.ignored or {},markerHeight=math.max(0.2,math.min(1.3,tonumber(options.markerHeight) or 0.65))}
end
function M.save(root,character,pins,options)
    local path=filename(root,character);if not path then return false,'No character selected.' end
    if ashita and ashita.fs then ashita.fs.create_dir(root..'/settings') end
    local records={}
    for key,entry in pairs(pins) do
        records[key]={kind=entry.kind,group=entry.group,name=entry.name,title=entry.title,
            symbol=entry.symbol,id=entry.id,key=entry.key,sourceItems=entry.sourceItems}
    end
    local ok,body=pcall(require('json').encode,{version=1,pins=records,options=options})
    if not ok then return false,body end
    local f,err=io.open(path..'.tmp','wb');if not f then return false,err end
    local wrote,writeErr=f:write(body);local closed,closeErr=f:close()
    if not wrote or not closed then return false,writeErr or closeErr end
    local previous=io.open(path,'rb')
    if previous then
        previous:close();os.remove(path..'.bak')
        local moved,moveErr=os.rename(path,path..'.bak');if not moved then return false,moveErr end
    end
    local moved,moveErr=os.rename(path..'.tmp',path)
    if not moved then os.rename(path..'.bak',path);return false,moveErr end
    return true
end
return M
