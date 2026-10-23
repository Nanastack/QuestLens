local M={enabled={false},keep={true}}
local imgui=require('imgui')
local store=require('lib.annotation_store')
local colors={{'Yellow',0x5544DDFF},{'Green',0x5544DD44},{'Blue',0x55FFAA44},{'Pink',0x55CC66FF}}
local color=1
local root,character,key,data,record,buffer
local drag,nearest,distance
local function save()
    if not character then return end
    local ok,err=store.save(root,character,data)
    if not ok then print('[QuestLens] Could not save notes/highlights: '..tostring(err)) end
end
function M.select(r,c,k)
    if root~=r or character~=c then
        root=r;character=c;data=store.load(r,c);key=nil
    end
    if key~=k then
        key=k;record=data[k]
        if type(record)~='table' then record={};data[k]=record end
        record.notes=type(record.notes)=='string' and record.notes or ''
        record.marks=type(record.marks)=='table' and record.marks or {}
        buffer={record.notes};drag=nil
    end
end
function M.controls()
    if not record then return end
    imgui.Checkbox('Highlight text',M.enabled)
    if M.enabled[1] then
        imgui.SameLine();imgui.Checkbox('Keep previous',M.keep)
        for i,c in ipairs(colors) do
            if i>1 then imgui.SameLine() end
            if imgui.RadioButton(c[1]..'##highlight',color==i) then color=i end
        end
        imgui.TextDisabled(M.keep[1] and 'Drag across guide text to add a highlight.' or 'Drag across guide text to replace previous highlights.')
    else drag=nil end
    if #record.marks>0 then
        if imgui.Button('Undo last highlight') then table.remove(record.marks);save() end
        imgui.SameLine()
        if imgui.Button('Clear guide highlights') then record.marks={};save() end
    end
end
function M.beginPage(page,blocks)
    M.page=(page.source or '')..':'..(page.title or '')
    M.blocks={};M.seen={};nearest=nil;distance=math.huge
    for i,b in ipairs(blocks or {}) do M.blocks[i]=b.annotationText end
end
local function point(x,y,text)
    local mouseX,mouseY=imgui.GetMousePos()
    local best,bestDistance=1,math.huge
    local i=1
    while i<=#text+1 do
        local w=imgui.CalcTextSize(text:sub(1,i-1))
        local d=math.abs(mouseX-(x+w))
        if d<bestDistance then best=i;bestDistance=d end
        i=i+1
        while i<=#text and text:byte(i)>=128 and text:byte(i)<192 do i=i+1 end
    end
    return best,mouseX,mouseY
end
local function bounds(mark,block,textLength)
    if mark.page~=M.page then return end
    local a,b=mark.a,mark.b
    if type(a)~='table' or type(b)~='table' then return end
    if a.block>b.block or (a.block==b.block and a.pos>b.pos) then a,b=b,a end
    if block<a.block or block>b.block then return end
    -- Match the exact rendered blocks, including intervening text, after refresh.
    for n,t in pairs(mark.texts or {}) do
        local index=tonumber(n)
        if M.blocks[index]~=t then return end
    end
    return block==a.block and a.pos or 1,block==b.block and b.pos or textLength+1
end
function M.run(block,offset,text)
    if not record or not imgui.GetItemRectMin then return end
    if not M.enabled[1] and #record.marks==0 then return end
    local index=M.blockIndex
    M.blocks[index]=block
    local x,y=imgui.GetItemRectMin();local x2,y2=imgui.GetItemRectMax()
    if type(x)~='number' or type(x2)~='number' then return end
    local function paint(mark)
        local a,b=bounds(mark,index,#block)
        if not a then return end
        local first,last=math.max(offset,a),math.min(offset+#text,b)
        if first>=last then return end
        local left=imgui.CalcTextSize(text:sub(1,first-offset))
        local right=imgui.CalcTextSize(text:sub(1,last-offset))
        imgui.GetWindowDrawList():AddRectFilled({x+left,y},{x+right,y2},colors[mark.color or 1][2],0)
    end
    for _,mark in ipairs(record.marks) do
        if type(mark)=='table' and colors[mark.color or 1] then paint(mark) end
    end
    if not M.enabled[1] then return end
    local hovered=imgui.IsItemHovered()
    if hovered and imgui.IsMouseClicked(0) then
        local pos=point(x,y,text)
        drag={page=M.page,a={block=index,pos=offset+pos-1},b={block=index,pos=offset+pos-1},color=color,texts={}}
    end
    if drag and drag.page==M.page then
        local pos,mx,my=point(x,y,text)
        local dx=math.max(x-mx,0,mx-x2);local dy=math.max(y-my,0,my-y2)
        local d=dx*dx+dy*dy
        if d<distance then nearest={block=index,pos=offset+pos-1};distance=d end
        paint(drag)
    end
end
function M.block(index,text)
    M.blockIndex=index;M.blocks[index]=text
end
function M.endPage()
    if not drag then return end
    if nearest then drag.b=nearest end
    if imgui.IsMouseReleased(0) then
        local a,b=drag.a.block,drag.b.block
        for n=math.min(a,b),math.max(a,b) do drag.texts[tostring(n)]=M.blocks[n] end
        if drag.a.block~=drag.b.block or drag.a.pos~=drag.b.pos then
            if not M.keep[1] then record.marks={} end
            record.marks[#record.marks+1]=drag;save()
        end
        drag=nil
    elseif not imgui.IsMouseDown(0) then drag=nil end
end
function M.notes()
    if not record then return end
    imgui.Spacing();imgui.Separator();imgui.TextUnformatted('My Notes')
    if imgui.InputTextMultiline('##quest-notes',buffer,16384,{-1,110}) then
        record.notes=buffer[1];save()
    end
    imgui.TextDisabled('Saved automatically for this character and guide.')
    local unmatched=0
    for _,mark in ipairs(record.marks) do
        local valid=mark.page==M.page
        for n,t in pairs(mark.texts or {}) do if M.blocks[tonumber(n)]~=t then valid=false end end
        if not valid then unmatched=unmatched+1 end
    end
    if unmatched>0 then imgui.TextWrapped(tostring(unmatched)..' saved highlight(s) do not match this guide version. Notes are unchanged.') end
end
return M
