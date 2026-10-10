local M={}
M.tabOrder={0,5,2,1,4,9,'wardrobes',3}
M.scanOrder={0,5,2,1,4,9,8,10,11,12,13,14,15,16,3}
M.wardrobes={8,10,11,12,13,14,15,16}
function M.quantity(item,bag)
    if bag==nil then return item.count end
    if bag=='wardrobes' then
        local total=0
        for _,id in ipairs(M.wardrobes) do total=total+(item.bags[id] or 0) end
        return total
    end
    return item.bags[bag] or 0
end
M.bags={[0]='Inventory',[1]='Mog Safe',[2]='Storage',[3]='Temporary',
    [4]='Mog Locker',[5]='Mog Satchel',[6]='Mog Sack',[7]='Mog Case',
    [8]='Wardrobe',[9]='Mog Safe 2',[10]='Wardrobe 2',[11]='Wardrobe 3',
    [12]='Wardrobe 4',[13]='Wardrobe 5',[14]='Wardrobe 6',[15]='Wardrobe 7',[16]='Wardrobe 8',wardrobes='Wardrobes'}
function M.scan(inv,resources)
    local items,unavailable={},{}
    for _,bag in ipairs(M.scanOrder) do
        local ok,max=pcall(inv.GetContainerCountMax,inv,bag)
        max=ok and tonumber(max) or 0
        if not max or max<=0 then unavailable[#unavailable+1]=M.bags[bag]
        else
            for slot=1,math.min(max,80) do
                local valid,item=pcall(inv.GetContainerItem,inv,bag,slot)
                if valid and item and tonumber(item.Id) and item.Id>0 and item.Count>0 then
                    local id=tonumber(item.Id)
                    local v=items[id]
                    if not v then
                        local found,r=pcall(resources.GetItemById,resources,id)
                        local name=found and r and r.Name and r.Name[1] or ('Item #'..id)
                        v={id=id,name=name,count=0,bags={}};items[id]=v
                    end
                    v.count=v.count+item.Count
                    v.bags[bag]=(v.bags[bag] or 0)+item.Count
                end
            end
        end
    end
    local list={};for _,v in pairs(items) do list[#list+1]=v end
    table.sort(list,function(a,b)return a.name<b.name end)
    return list,unavailable
end
return M
