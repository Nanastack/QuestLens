local M={}
local function norm(s)
    return s:lower():gsub('two[%s%-]*leaf','2leaf'):gsub('mandragora','mandra'):gsub('[^a-z0-9]','')
end
function M.describe(title,rows,known,required,bags)
    if not known then return nil end
    for _,item in ipairs(rows) do
        if norm(item.name)==norm(title) then
            local locations={}
            for bag,count in pairs(item.bags or {}) do
                if bag~=0 and count>0 then locations[#locations+1]=(bags[bag] or tostring(bag))..': '..count end
            end
            table.sort(locations)
            local amount=required or 1
            return {owned=item.count>=amount,inventory=(item.bags[0] or 0)>=amount,
                count=item.count,locations=table.concat(locations,', '),quantityKnown=required~=nil}
        end
    end
end
return M
