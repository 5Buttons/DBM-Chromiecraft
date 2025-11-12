local mod	= DBM:NewMod("Krystallus", "DBM-Party-WotLK", 7)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251112220131")
mod:SetCreatureID(27977)
mod:SetEncounterID(563)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"UNIT_SPELLCAST_SUCCEEDED"
)

local specWarningShatter	= mod:NewSpecialWarningMoveAway(50810, nil, nil, nil, 1, 2)
local timerGroundSlamCD		= mod:NewCDTimer(20, 50833, nil, nil, nil, 3)

mod:AddRangeFrameOption("10")

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == GetSpellInfo(50827) and self:AntiSpam(5, 2) then  -- Ground Slam
		specWarningShatter:Show()
		specWarningShatter:Play("scatter")
		timerGroundSlamCD:Start()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(10)
		end
		elseif spellName == GetSpellInfo(50810) and self:AntiSpam(5, 3) then  -- Shatter
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end
