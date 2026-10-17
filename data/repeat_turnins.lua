-- Verified static completed-section trade recipes from Phoenix scripts. Alternatives are OR; items within each recipe are AND.
local recipes={["AHT_URHGAN:15"]={{{id=5455,count=1},{id=5453,count=1},{id=5136,count=1},{id=5456,count=1},{id=5454,count=1}}},["WINDURST:25"]={{{id=498,count=4}}}}

-- Phoenix Yoran-Oran.lua: each branch accepts ONE of these items, not all five.
recipes['WINDURST:34']={{{id=17344,count=1}},{{id=934,count=1}},{{id=1154,count=1}},{{id=4369,count=1}},{{id=1150,count=1}}}
return recipes
