local M={}
local fields={['Fame level required']=true,['Starts with']=true,Zone=true,Map=true,
    Requires=true,['Previous quest']=true,['Previous Quest']=true,['Next Quest']=true,
    ['Required Fame']=true,['Level Restriction:']=true,['Starting NPC']=true,
    Pack=true,Title=true,Repeatable=true,Unlocks=true,Rewards=true}
local headings={Walkthrough=true,['How to obtain']=true,['Related items']=true,
    Rewards=true,['Involved NPCs']=true,Notes=true,Requirements=true}
function M.blocks(text)
    local lines={};for line in (text..'\n'):gmatch('(.-)\n') do lines[#lines+1]=line:gsub('\r','') end
    local blocks={};local paragraph={};local inGuide=false;local requirements=false
    local function flush()
        if #paragraph>0 then blocks[#blocks+1]={text=table.concat(paragraph,' ')};paragraph={} end
    end
    local i=1
    while i<=#lines do
        local line=lines[i]:match('^%s*(.-)%s*$')
        if line=='' then flush()
        elseif line:find('Generated from Phoenix',1,true) or line:find('Source: BG-Wiki',1,true) then
            flush();local source={line}
            for j=i+1,#lines do source[#source+1]=lines[j] end
            blocks[#blocks+1]={text=table.concat(source,' '),source=true};break
        elseif fields[line] and not inGuide then
            flush()
            local j=i+1
            while j<=#lines and not lines[j]:match('%S') do j=j+1 end
            -- BG's two-column quest navigation flattens headers before values.
            if line=='Previous Quest' and lines[j] and lines[j]:match('^%s*(.-)%s*$')=='Next Quest' then
                j=j+1
                local values={}
                while j<=#lines and #values<2 do
                    local v=lines[j]:match('^%s*(.-)%s*$')
                    if fields[v] or headings[v] then break end
                    if v~='' then values[#values+1]=v end
                    j=j+1
                end
                blocks[#blocks+1]={text='Previous quest: '..(values[1] or 'Not listed'),field=true}
                blocks[#blocks+1]={text='Next quest: '..(values[2] or 'Not listed'),field=true}
            else
                local values={}
                while j<=#lines do
                    local v=lines[j]:match('^%s*(.-)%s*$')
                    if v=='' or fields[v] or headings[v] then break end
                    values[#values+1]=v;j=j+1
                end
                local label=line:gsub(':$','')
                if label=='Pack' then label='Expansion / add-on' end
                if label=='Title' then label='Title reward' end
                blocks[#blocks+1]={text=label..': '..(#values>0 and table.concat(values,' / ') or 'Not listed'),field=true}
            end
            i=j-1
        elseif headings[line] then
            requirements=line=='Requirements'
            flush();inGuide=true;blocks[#blocks+1]={text=line,heading=true}
        elseif line=='Description' then
            flush();blocks[#blocks+1]={text=line,heading=true}
        else
            if requirements then flush();blocks[#blocks+1]={text=line}
            else paragraph[#paragraph+1]=line end
        end
        i=i+1
    end
    flush();return blocks
end
return M
