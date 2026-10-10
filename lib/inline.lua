local M={}
-- Match the page's link labels in its cached plain text, longest label first.
function M.spans(text,links)
    local labels={}
    local seen={}
    local function add(label,title)
        if type(label)=='string' and #label>1 and not seen[label:lower()] then
            seen[label:lower()]=true;labels[#labels+1]={label=label,title=title}
        end
    end
    for _,v in ipairs(links or {}) do
        add(v.label,v.title)
        for _,alias in ipairs(v.aliases or {}) do add(alias,v.title) end
        add(v.title,v.title)
    end
    table.sort(labels,function(a,b)return #a.label>#b.label end)
    local out={};local start,pos=1,1;local lower=text:lower()
    while pos<=#text do
        local found
        for _,v in ipairs(labels) do
            local last=pos+#v.label-1
            local before=pos>1 and lower:sub(pos-1,pos-1) or ''
            local after=lower:sub(last+1,last+1)
            if lower:sub(pos,last)==v.label:lower() and not before:match('[%w_]') and
                (not after:match('[%w_]') or (after=='s' and not lower:sub(last+2,last+2):match('[%w_]'))) then
                found=v;break
            end
        end
        if found then
            if start<pos then out[#out+1]={text=text:sub(start,pos-1)} end
            out[#out+1]={text=text:sub(pos,pos+#found.label-1),title=found.title}
            pos=pos+#found.label;start=pos
        else pos=pos+1 end
    end
    if start<=#text then out[#out+1]={text=text:sub(start)} end
    return out
end
return M
