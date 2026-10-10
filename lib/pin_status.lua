local M={}
function M.missingItems(entry,inventory)
    local owned={};for _,item in ipairs(inventory) do owned[item.id]=(owned[item.id] or 0)+item.count end
    local missing={}
    for _,item in ipairs(entry.sourceItems or {}) do
        if not owned[item.id] or owned[item.id]<=0 then missing[#missing+1]=item.name or ('Item #'..item.id) end
    end
    return missing
end
function M.followup(page)
    if not page or page.error then return nil end
    local blocks=require('lib.readable').blocks(page.text or '')
    for _,block in ipairs(blocks) do
        local title=block.text:match('^[Nn]ext [Qq]uest:%s*(.+)$')
        if title and title~='None' and title~='Not listed' and title~='N/A' then
            for _,link in ipairs(page.links or {}) do
                if link.label==title or link.title==title then return link.title end
            end
            return title
        end
    end
end
function M.repeatability(page)
    if not page or page.error then return 'Repeatability unknown' end
    local text=(page.text or ''):lower()
    local value=text:match('repeatable%s*:?%s*\n%s*(%a+)') or text:match('repeatable:%s*(%a+)')
    if value=='yes' or value=='true' then return 'Repeatable' end
    if value=='no' or value=='false' then return 'Not repeatable' end
    -- Explicit local-guide declarations, rather than inferring from a quest name.
    if page.localGuide and text:find('repeatable%.') then return 'Repeatable' end
    return 'Repeatability unknown'
end
return M
