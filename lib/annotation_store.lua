local M={}
local allowed={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,OTHER_AREAS=true,
    OUTLANDS=true,AHT_URHGAN=true,ZILART=true,COP=true,TOAU=true,ASSAULT=true}
local function filename(root,character)
    if type(character)~='string' or not character:match('^[%w%-]+$') then return nil end
    return root..'/settings/annotations-'..character:lower()..'.json'
end
local function read(path)
    local f=io.open(path,'rb');if not f then return nil end
    local body=f:read('*a');f:close()
    local ok,data=pcall(require('json').decode,body)
    if ok and type(data)=='table' and data.version==1 and type(data.pins)=='table' then return data end
end
function M.load(root,character)
    local path=filename(root,character)
    local data=path and (read(path) or read(path..'.bak')) or {}
    return type(data.guides)=='table' and data.guides or {}
end
function M.save(root,character,guides)
    local path=filename(root,character);if not path then return false,'No character selected.' end
    if ashita and ashita.fs then ashita.fs.create_dir(root..'/settings') end
    local ok,body=pcall(require('json').encode,{version=1,pins={},guides=guides})
    if not ok then return false,body end
    local f,err=io.open(path..'.tmp','wb');if not f then return false,err end
    local wrote=f:write(body);local closed=f:close();if not wrote or not closed then return false,'Write failed' end
    os.remove(path..'.bak')
    local old=io.open(path,'rb');if old then old:close();local moved,e=os.rename(path,path..'.bak');if not moved then return false,e end end
    local moved,e=os.rename(path..'.tmp',path);if not moved then os.rename(path..'.bak',path);return false,e end
    return true
end
return M
