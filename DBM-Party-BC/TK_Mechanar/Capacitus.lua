local mod = DBM:NewMod(563, "DBM-Party-BC", 13, 258)
local L = mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251017120000")
mod:SetCreatureID(19219)
mod:SetModelID(19162)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 35158 35159",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_AURA player"
)

local warnPolarity			= mod:NewAnnounce("WarnPolarity", 2)
local warnMagicShield		= mod:NewSpellAnnounce(35158, 3)
local warnDamageShield		= mod:NewSpellAnnounce(35159, 3)

local timerMagicShield		= mod:NewBuffActiveTimer(10, 35158, nil, nil, nil, 5)
local timerDamageShield		= mod:NewBuffActiveTimer(10, 35159, nil, nil, nil, 5)
local timerNextShift		= mod:NewCDTimer(30, 39096, nil, nil, nil, 2)

local warnChargeChanged		= mod:NewSpecialWarning("WarningChargeChanged", nil, nil, nil, 3, 2, nil, nil, 39096)
local warnChargeNotChanged	= mod:NewSpecialWarning("WarningChargeNotChanged", false, nil, nil, 1, 12, nil, nil, 39096)

local yellShift				= mod:NewShortPosYell(39096, DBM_CORE_L.AUTO_YELL_CUSTOM_POSITION)

local enrageTimer			= mod:NewBerserkTimer(180)

local currentCharge
local yellCount = 0
mod.vb.lastShift = nil

function mod:OnCombatStart(delay)
	currentCharge = nil
	yellCount = 0
	self.vb.lastShift = nil
	if self:IsHeroic() then
		enrageTimer:Start(-delay)
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(unitId, spellName)
	if spellName == "Polarity Shift" and self:AntiSpam(5, 1) then
		warnPolarity:Show()
		timerNextShift:Start()
		yellCount = 0  -- Reset yell count for each new shift
		self.vb.lastShift = true
		self:ScheduleMethod(0.1, "CheckCharge")
	end
end

function mod:CheckCharge()
	local charge
	local i = 1
	while UnitDebuff("player", i) do
		local _, _, icon = UnitDebuff("player", i)
		if icon == "Interface\\Icons\\Spell_ChargeNegative" then
			charge = "Negative Charge"
			if yellCount < 3 then
				yellShift:Yell(7, "- -")
				yellCount = yellCount + 1
			end
			break
		elseif icon == "Interface\\Icons\\Spell_ChargePositive" then
			charge = "Positive Charge"
			if yellCount < 3 then
				yellShift:Yell(6, "+ +")
				yellCount = yellCount + 1
			end
			break
		end
		i = i + 1
	end
	if charge then
		self.vb.lastShift = nil
		if charge == currentCharge then
			warnChargeNotChanged:Show()
			warnChargeNotChanged:Play("dontmove")
		else
			warnChargeChanged:Show(charge)
			warnChargeChanged:Play("stilldanger")
		end
		currentCharge = charge
	end
end

function mod:UNIT_AURA()
	if not self.vb.lastShift then return end
	self:CheckCharge()
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 35158 then		--Magic Shield
		warnMagicShield:Show(args.destName)
		timerMagicShield:Start()
	elseif args.spellId == 35159 then	--Damage Shield
		warnDamageShield:Show(args.destName)
		timerDamageShield:Start()
	end
end