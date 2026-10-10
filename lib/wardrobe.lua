local M={}
local advanced={"A Knight's Test",'Ayame and Kaede','Blade of Darkness','I Can Hear a Rainbow',
    'The Fanged One','Path of the Bard','Path of the Beastmaster','Forge Your Destiny',
    'An Empty Vessel','Luck of the Draw','No Strings Attached','The Holy Crest'}
local rules={}
for _,title in ipairs(advanced) do rules[title]='first advanced-job unlock only; shared across all advanced jobs' end
rules['Elder Memories']='first support-job unlock only; shared with The Old Lady'
rules['The Old Lady']='first support-job unlock only; shared with Elder Memories'
rules['Divine Might']='once per character; shared with Ark Angels'
rules['Ark Angels']='once per character; shared with Divine Might'
local nation={"The Zeruhn Report",'Fetichism','The Emissary','Jeuno','Magicite',
    'Xarcabard, Land of Truths',"The Pirate's Cove",'On My Way','Enter the Talekeeper','Where Two Paths Converge',
    'Smash the Orcish Scouts','Save the Children','Journey Abroad','Appointment to Jeuno',
    'The Shadow Lord',"Ranperre's Final Rest",'The Secret Weapon','Lightbringer','The Heir to the Light',
    'The Horutoto Ruins Experiment','The Price of Peace','The Three Kingdoms','A New Journey',
    'The Shadow Awaits','Saintly Invitation','Awakening of the Gods',"The Jester Who'd be King",'Moon Reading'}
for _,title in ipairs(nation) do rules[title]='once per milestone; shared across all three nations' end
function M.apply(title,text)
    if not text or not text:lower():find('wardrobe',1,true) or not text:match('%+%d') then return text end
    local rule=rules[title]
    if not rule then return text,'Wardrobe slots are awarded once per character for this milestone; repeating it gives no additional slots.' end
    local lines={}
    for line in (text..'\n'):gmatch('(.-)\n') do
        if line:lower():find('wardrobe',1,true) and line:match('%+%d') then
            line=line:gsub('%s*%([^)]*%)','')..' ('..rule..')'
        end
        lines[#lines+1]=line
    end
    return table.concat(lines,'\n'),'Wardrobe reward: '..rule..'. Completing another quest or mission in this shared group does not grant those slots again.'
end
return M
