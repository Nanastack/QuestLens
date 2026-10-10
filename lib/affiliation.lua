local M={}
local fame=require('data.quest_fame')
local nations={SANDORIA={file='sandoria.png',name="San d'Oria"},BASTOK={file='bastok.png',name='Bastok'},WINDURST={file='windurst.png',name='Windurst'}}
local expansions={ZILART={file='zilart.png',name='Rise of the Zilart'},COP={file='cop.png',name='Chains of Promathia'},TOAU={file='toau.png',name='Treasures of Aht Urhgan'},ASSAULT={file='toau.png',name='Treasures of Aht Urhgan'},AHT_URHGAN={file='toau.png',name='Treasures of Aht Urhgan'}}
local function norm(s)return (s or ''):lower():gsub('[^%w]',''):gsub('_','') end
local mogHouse={giveamoogleabreak=true,themooglepicnic=true,themooglespicnic=true,
    mooglesinthewild=true,growingflowers=true,aladysheart=true,flowerchild=true,keepingnotes=true}
function M.forEntry(entry)
    local icons={}
    if entry.kind=='Quest' and mogHouse[norm(entry.symbol or entry.name or entry.title)] then
        return {{file='moogle.png',label='Mog House quest'}}
    end
    if entry.kind=='Quest' and entry.group=='JEUNO' then
        return {{file='jeuno.png',label='Jeuno quest origin'}}
    end
    if entry.kind=='Quest' then
        local areas=fame[norm(entry.symbol or entry.name or entry.title)]
        for _,area in ipairs(areas or {}) do
            local nation=nations[area]
            if nation then icons[#icons+1]={file=nation.file,label='Fame reward: '..nation.name} end
        end
        if #icons>0 then return icons end
    end
    local nation=nations[entry.group]
    if nation then
        icons[1]={file=nation.file,label=nation.name..(entry.kind=='Quest' and ' quest origin; fame reward not verified.' or ' missions')}
    elseif expansions[entry.group] then
        local expansion=expansions[entry.group]
        icons[1]={file=expansion.file,label=expansion.name}
    end
    return icons
end
return M
