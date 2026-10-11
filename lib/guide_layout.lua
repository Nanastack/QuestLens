-- Cache word measurements and combine each linked/plain span into line runs.
local M={}
function M.runs(span,width,start,measure,fontKey)
    local cache=span.layout
    if not cache or cache.fontKey~=fontKey then
        cache={fontKey=fontKey,tokens={}};span.layout=cache
        local pos=1
        while pos<=#span.text do
            local rest=span.text:sub(pos)
            local token=rest:match('^%s+') or rest:match('^%S+')
            local _,breaks=token:gsub('\n','')
            cache.tokens[#cache.tokens+1]={text=token,space=token:match('^%s+$')~=nil,breaks=breaks,width=breaks==0 and measure(token) or 0}
            pos=pos+#token
        end
    end
    if cache.width==width and cache.start==start then return cache.runs,cache.used end
    local runs,used={},start
    local current
    local function flush() if current then runs[#runs+1]=current;current=nil end end
    local forced=false
    for _,token in ipairs(cache.tokens) do
        if token.breaks>0 then
            flush();used=0;forced=true
            if token.breaks>1 then runs[#runs+1]={blankLines=token.breaks-1} end
        elseif not token.space or used>0 then
            if used>0 and used+token.width>width then flush();used=0;forced=true end
            if not token.space or used>0 then
                if not current then current={text='',sameLine=used>0 and not forced};forced=false end
                current.text=current.text..token.text;used=used+token.width
            end
        end
    end
    flush();cache.width=width;cache.start=start;cache.runs=runs;cache.used=used
    return runs,used
end
return M
