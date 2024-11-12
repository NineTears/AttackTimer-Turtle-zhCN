--==================================================
-- Attack Timer - ver 1.00
-- 日期: 2024年4月11日
-- 作者: 凡人
-- 描述: 显示你近战自动攻击、远程自动射击的间隔时间
-- 版权所有: 凡人
-- 鸣谢: 随风随行, Udokus, 独孤傲雪
--==================================================
local L = AttackTimer.L
AttackTimer.LastTime = 0
AttackTimer.PercentTime = 0
AttackTimer.Remainder = 0

--登录游戏后的武器速度，重载会变，换武器不变，获得加速BUFF不变
local function LastSpeed()
    local speedMH = UnitAttackSpeed("player")
    return speedMH
end

local mainWeapon = nil
local function AttackTimerUpdateWeapon()
	mainWeapon = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
end

--是否乌龟服
local function IsTurtleServer()
	local _, build = GetBuildInfo()
	if build and tonumber(build) > 6141 then
		return true
	end
	return false
end

--要监听的事件
local events = {
	--近战
	"CHAT_MSG_COMBAT_SELF_HITS", 
	"CHAT_MSG_COMBAT_SELF_MISSES", 
	"CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", 
	"CHAT_MSG_SPELL_SELF_DAMAGE", 
	--远程
	"START_AUTOREPEAT_SPELL", 
	"STOP_AUTOREPEAT_SPELL", 
	"ITEM_LOCK_CHANGED", 
	--换武器
	"UNIT_INVENTORY_CHANGED", 
	--效果
	"CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
	"CHAT_MSG_SPELL_AURA_GONE_SELF",
}

--会重置攻击的技能请自行添加
local spells = {
	L["Slam"],
	L["Decisive Strike"],
	L["Heroic Strike"],
	L["Raptor Strike"],
	L["Cleave"],
	L["Maul"],
	L["Holy Strike"],	
}

--注册事件
function AttackTimer_OnLoad()
	if not IsTurtleServer() then
		table.remove(spells, 7)
		table.remove(events, 9)
		table.remove(events, 10)
	end

	for _, event in pairs(events) do
		this:RegisterEvent(event)
	end
	
	AttackTimerUpdateWeapon()
end

--计时条逻辑
local Weapon_Time = 0
local StartShoot = false
local BarText = ""
local sSTold
local prevWepSpeed = nil

local function ResetAttack(max, icon)
	Weapon_Time = max
	AttackTimer.LastTime = GetTime()
	BarText = L["Attack"]
	AttackTimerBar:SetMinMaxValues(0, max)
	AttackTimerFrameIcon:SetTexture(icon)
end

local function AttackTimer_OnAttack(status)
	local mainS, offS = UnitAttackSpeed("player");
	local rangedS = UnitRangedDamage("player")
	prevWepSpeed = mainS
	
	local AttackResetTime = (Weapon_Time / mainS) < 0.025
	local RangedResetTime = (Weapon_Time / rangedS) < 0.025
	local AttackIcon = GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot"))
	local RangedIcon = GetInventoryItemTexture("player", GetInventorySlotInfo("RangedSlot"))
	
	if status == "Reset" then
		ResetAttack(mainS, AttackIcon)
	elseif status == "Attack" then
		if not offS then
			ResetAttack(mainS, AttackIcon)
		else
			if AttackResetTime then
				ResetAttack(mainS, AttackIcon)
			end
		end
	elseif status == "Ranged" then
		if StartShoot == true then
			--GCD检查
			local id = GetSpellIndex(L["Serpent Sting"])
			if id then
				local start, duration = GetSpellCooldown(id, "BOOKTYPE_SPELL")
				if ( duration ~= 1.5 ) and RangedResetTime then
					Weapon_Time = rangedS
					AttackTimer.LastTime = GetTime()
				elseif ( sSTold == start ) and RangedResetTime then
					Weapon_Time = rangedS
					AttackTimer.LastTime = GetTime()
				else
					sSTold = start
				end
			else
				Weapon_Time = rangedS
			end
			BarText = L["AutoShoot"]
			AttackTimerBar:SetMinMaxValues(0, rangedS)
			AttackTimerFrameIcon:SetTexture(RangedIcon)
		end	
	end
	
	LibIconBorder(AttackTimerFrame)
	AttackTimerBar:SetStatusBarColor(0, 1, 0);
	AttackTimerBar:SetValue(0);
	AttackTimerBarSpark:Show();
	AttackTimerBar:Show();
end

--事件
local Attack_Strings = {
	COMBATHITABSORBSELFOTHER,	--你击中%s造成%d伤害（%d被吸收）。
	COMBATHITSELFOTHER,			--你击中%s造成%d点伤害。
	IMMUNESELFOTHER,			--你击中了%s，但是目标对攻击免疫。
	IMMUNESELFSELF,				--你击中了自己，但是你对攻击免疫。
	COMBATHITCRITSELFOTHER,		--你对%s造成%d的致命一击伤害。
}

for index in Attack_Strings do
	for _, pattern in {"%%s", "%%d"} do
		Attack_Strings[index] = gsub(Attack_Strings[index], pattern, "(.*)")
	end
end

--普通攻击、致命一击
function AttackTimer:CHAT_MSG_COMBAT_SELF_HITS()	
	for _, str in Attack_Strings do
		if string.find(arg1, str) then
			AttackTimer_OnAttack("Attack")
		end
	end
end

--非正常击中
function AttackTimer:CHAT_MSG_COMBAT_SELF_MISSES()	
	AttackTimer_OnAttack("Attack")
end

local Parry_Strings = {
	VSPARRYOTHERSELF,	--"%s发起了攻击。你招架住了。"
}

for index in Parry_Strings do
	for _, pattern in {"%%s", "%%d"} do
		Parry_Strings[index] = gsub(Parry_Strings[index], pattern, "(.*)")
	end
end

--你的招架了目标的攻击
function AttackTimer:CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES()	
	for _, str in Parry_Strings do
		if string.find(arg1, str) then
		local minimum = LastSpeed() * 0.20
			if (Weapon_Time > minimum) then
				local reduct = LastSpeed() * 0.40
				local newTimer = Weapon_Time - reduct
				if (newTimer < minimum) then
					Weapon_Time = minimum
				else
					Weapon_Time = newTimer
				end
			end
		end
	end
end

--技能伤害
function AttackTimer:CHAT_MSG_SPELL_SELF_DAMAGE()
	for _, v in pairs(spells) do
		if string.find(arg1, v) then
			AttackTimer_OnAttack("Reset")
		end
	end
end

--换装备
function AttackTimer:UNIT_INVENTORY_CHANGED()	
	if (arg1 == "player") then
		local oldWep = mainWeapon
		AttackTimerUpdateWeapon()
		if (UnitAffectingCombat("player") and oldWep ~= mainWeapon) then
			AttackTimer_OnAttack("Reset")
		end
	end
end

--开始自动射击
function AttackTimer:START_AUTOREPEAT_SPELL()	
	StartShoot = true
end

--停止自动射击
function AttackTimer:STOP_AUTOREPEAT_SPELL()	
	StartShoot = false
end

--装备变化
function AttackTimer:ITEM_LOCK_CHANGED()	
	AttackTimer_OnAttack("Ranged")
end

local function AttackTime_Speed()
	local _, max = AttackTimerBar:GetMinMaxValues()
	local curvalue = AttackTimerBar:GetValue()
	if (string.find(arg1, L["Flurry"])) then
		if (prevWepSpeed ~= nil) then
			local newSpeed = LastSpeed()
			if (prevWepSpeed ~= newSpeed) and ((curvalue / max) ~= 0) then
				local perc = Weapon_Time / prevWepSpeed
				Weapon_Time = newSpeed * perc
			end
		end
	end
end

function AttackTimer:CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS()
	AttackTime_Speed()
end

function AttackTimer:CHAT_MSG_SPELL_AURA_GONE_SELF()
	AttackTime_Speed()
end

function AttackTimer_OnEvent()	
	if (AttackTimer[event]) then
		AttackTimer[event](this, arg1)
	end
end

--刷新
function AttackTimer_OnUpdate(elapsed)
	local min, max = AttackTimerBar:GetMinMaxValues();
	local curvalue = AttackTimerBar:GetValue()

	--Weapon_Time等于主武器攻速，随着arg1减少直到0
	if (Weapon_Time > 0) then
		Weapon_Time = Weapon_Time - elapsed
		if (Weapon_Time < 0) then
			Weapon_Time = 0
		end
	end		

	AttackTimer.PercentTime = Round((max - Weapon_Time)/max*100)
	AttackTimer.Remainder = max - curvalue
	
	AttackTimerBarText:SetText(BarText.." "..format("%0.1f", max - Weapon_Time));
	AttackTimerBar:SetValue(max - Weapon_Time);
	
	local sparkPosition = ((max - Weapon_Time) / max) * this:GetWidth();
	if sparkPosition < 0 then
		sparkPosition = 0;
	end
	
	AttackTimerBarSpark:SetPoint("CENTER", AttackTimerBar, "LEFT", sparkPosition, 1);
	
	--脱离战斗且最大值则隐藏
	if Weapon_Time == 0 and not UnitAffectingCombat("player") then
		local alpha = this:GetAlpha() - CASTING_BAR_ALPHA_STEP
		if alpha > 0 then
			this:SetAlpha(alpha)
		else
			this:SetAlpha(0)
			this:Hide()
		end
	else
		this:SetAlpha(1)
	end
end

--移动
function AttackTimer_AjustPosition()
	if (AttackTimerMove:IsVisible()) then
		AttackTimerMove:Hide();
	else
		AttackTimerMove:Show();
	end
end