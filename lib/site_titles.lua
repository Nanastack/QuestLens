local M={}
-- Phoenix adds sequence numbers; BG uses distinct punctuation for this chain.
local bg={
    cursesfoiledagain1='Curses, Foiled Again!',
    cursesfoiledagain2='Curses, Foiled...Again!?',
    cursesfoiledagolem='Curses, Foiled A-Golem!?',
    tobeeornottobee='To Bee or Not to Bee?',
    lostforwords='Lost for Words',
}
function M.resolve(title,site)
    if site~='BG' then return title end
    return bg[title:lower():gsub('[^a-z0-9]','')] or title
end
return M
