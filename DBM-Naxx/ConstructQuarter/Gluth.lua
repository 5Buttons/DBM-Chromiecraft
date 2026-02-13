local mod	= DBM:NewMod("Gluth", "DBM-Naxx", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260213210603")
mod:SetCreatureID(15932)
mod:SetEncounterID(1108)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 28371 54427",
	"SPELL_AURA_REMOVED 28371 54427",
	"UNIT_SPELLCAST_SUCCEEDED"
)

local warnEnrage		= mod:NewTargetNoFilterAnnounce(28371, 3, nil , "Healer|Tank|RemoveEnrage", 2)
local warnDecimateSoon	= mod:NewSoonAnnounce(28374, 2)
local warnDecimateNow	= mod:NewSpellAnnounce(28374, 3)

local specWarnEnrage	= mod:NewSpecialWarningDispel(28371, "RemoveEnrage", nil, nil, 1, 6)

local timerEnrage		= mod:NewBuffActiveTimer(8, 28371, nil, nil, nil, 5, nil, DBM_COMMON_L.ENRAGE_ICON)
local timerDecimate		= mod:NewCDTimer(110, 28374, nil, nil, nil, 2)
local enrageTimer		= mod:NewBerserkTimer(360)

local function getDecimateTimer()
	if mod:IsDifficulty("normal25", "heroic25") or mod:IsHeroic() then
		return 90 -- 25-man
	else
		return 110 -- 10-man
	end
end

function mod:OnCombatStart(delay)
	enrageTimer:Start(360 - delay)
	local decimateTime = getDecimateTimer()
	timerDecimate:Start(decimateTime - delay)
	warnDecimateSoon:Schedule(decimateTime - 10 - delay)
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 28371 or args.spellId == 54427 then
		if self.Options.SpecWarn28371dispel then
			specWarnEnrage:Show(args.destName)
			specWarnEnrage:Play("enrage")
		else
			warnEnrage:Show(args.destName)
		end
		timerEnrage:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 28371 or args.spellId == 54427 then
		timerEnrage:Stop()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if (spellName == GetSpellInfo(28374) or spellName == GetSpellInfo(54426)) and self:AntiSpam(5, 1) then
		local decimateTime = getDecimateTimer()
		warnDecimateNow:Show()
		timerDecimate:Start(decimateTime)
		warnDecimateSoon:Schedule(decimateTime - 10)
	end
end