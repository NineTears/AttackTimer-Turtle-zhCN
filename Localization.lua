local AttackTimer = _G.AttackTimer or {};
_G.AttackTimer = AttackTimer;
local function LocaleFunc(L, key) return key end
local L = setmetatable({}, {__index = LocaleFunc})
AttackTimer.L = L

if (GetLocale() == "zhCN") then
	L["Attack"] = "攻击"
	L["Slam"] = "猛击"
	L["Decisive Strike"] = "果断一击"
	L["Heroic Strike"] = "英勇打击"
	L["Raptor Strike"] = "猛禽一击"
	L["Cleave"] = "顺劈斩"
	L["Maul"] = "槌击"
	L["Holy Strike"] = "神圣打击"
	L["AutoShoot"] = "自动射击"
	L["Serpent Sting"] = "毒蛇钉刺"
	L["Flurry"] = "乱舞"
else
	L["Attack"] = true
	L["Slam"] = true
	L["Decisive Strike"] = true
	L["Heroic Strike"] = true
	L["Raptor Strike"] = true
	L["Cleave"] = true
	L["Maul"] = true
	L["Holy Strike"] = true
	L["AutoShoot"] = true
	L["Serpent Sting"] = true
	L["Flurry"] = true
end