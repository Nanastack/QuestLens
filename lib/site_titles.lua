local M={}
-- Phoenix adds sequence numbers; BG uses distinct punctuation for this chain.
local bg={
    cursesfoiledagain1='Curses, Foiled Again!',
    cursesfoiledagain2='Curses, Foiled...Again!?',
    cursesfoiledagolem='Curses, Foiled A-Golem!?',
    tobeeornottobee='To Bee or Not to Bee?',
    lostforwords='Lost for Words',
}
local missionBranches={
    thethreekingdoms={phoenix='The Three Kingdoms',bg='Windurst Mission 2-3',suffixes={['']=true,sandoria=true,bastok=true,sandoria2=true,bastok2=true}},
    journeyabroad={phoenix='Journey Abroad',bg="San d'Oria Mission 2-3",suffixes={['']=true}},
    journeyto={phoenix='Journey Abroad',bg="San d'Oria Mission 2-3",suffixes={bastok=true,windurst=true,bastok2=true,windurst2=true}},
    theemissary={phoenix='The Emissary',bg='Bastok Mission 2-3',suffixes={['']=true,sandoria=true,windurst=true,sandoria2=true,windurst2=true}},
}
function M.resolve(title,site)
    if type(title)~='string' then return title end
    local normalized=title:lower():gsub('[^a-z0-9]','')
    for prefix,mission in pairs(missionBranches) do
        if normalized:sub(1,#prefix)==prefix and mission.suffixes[normalized:sub(#prefix+1)] then
            if site=='BG' then return mission.bg end
            if site=='Phoenix' then return mission.phoenix end
        end
    end
    if site~='BG' then return title end
    return bg[normalized] or title
end
return M
