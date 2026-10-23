-- Only script-derived associations qualify as requirements. Related wiki links alone do not.
local M={}
local function norm(s)return (s or ''):lower():gsub('[^a-z0-9]','') end
function M.verified(id,title,index,resolve)
    local guide=norm(resolve(title))
    if guide=='' then return false end
    for _,quest in ipairs(index[id] or {}) do
        if norm(resolve(quest.title))==guide then return true end
    end
    return false
end
return M
