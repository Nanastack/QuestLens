local M={}
local allowed={SANDORIA=true,BASTOK=true,WINDURST=true,JEUNO=true,OTHER_AREAS=true,OUTLANDS=true,AHT_URHGAN=true}
function M.new()return {groups={}} end
function M.update(observer,state,catalog)
    local added={}
    for group,ids in pairs(state.quests) do
        local names=catalog.quests[group]
        if names and allowed[group] then
            local previous=observer.groups[group]
            local snapshot={}
            for id in pairs(ids) do
                snapshot[id]=true
                if previous and not previous[id] then
                    added[#added+1]={kind='Quest',group=group,id=id,
                        name=names[id] or (group..' #'..id),key='Quest:'..group..':'..id}
                end
            end
            observer.groups[group]=snapshot
        end
    end
    table.sort(added,function(a,b)return a.key<b.key end)
    return added
end
return M
