local M={}
-- Phoenix adds sequence numbers; BG uses distinct punctuation for this chain.
local bg={
    cursesfoiledagain1='Curses, Foiled Again!',
    cursesfoiledagain2='Curses, Foiled...Again!?',
    cursesfoiledagolem='Curses, Foiled A-Golem!?',
    tobeeornottobee='To Bee or Not to Bee?',
    lostforwords='Lost for Words',
    wildcard='Wild Card (Quest)',
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
M.guideTitles={wildcard=true}
function M.configureGuides(catalog,aliases)
    local allowed={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,OTHER_AREAS=true,OUTLANDS=true,AHT_URHGAN=true,ZILART=true,COP=true,TOAU=true,ASSAULT=true}
    local function add(title) M.guideTitles[title:lower():gsub('[^a-z0-9]','')]=true end
    for _,kind in ipairs({'quests','missions'}) do
        for group,names in pairs(catalog[kind] or {}) do
            if allowed[group] then
                for _,name in pairs(names) do add(name);add(M.resolve(name,'Phoenix'));add(M.resolve(name,'BG')) end
            end
        end
    end
    for key,name in pairs(aliases or {}) do if M.guideTitles[key] then add(name) end end
end
function M.requiresWalkthrough(title)
    return type(title)=='string' and M.guideTitles[title:lower():gsub('[^a-z0-9]','')]==true
end
function M.needsFallback(title,page)
    if not M.requiresWalkthrough(title) or not page or page.error or page.localGuide then return false end
    if page.source=='BG' then
        return title:lower():gsub('[^a-z0-9]','')=='wildcard' and (page.title or ''):lower():gsub('[^a-z0-9]','')~='wildcardquest'
    end
    local text='\n'..(page.text or ''):gsub('\r','')..'\n'
    return not text:lower():find('\n%s*walkthrough%s*\n')
end
return M
