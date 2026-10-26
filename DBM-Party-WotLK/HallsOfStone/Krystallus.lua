local mod	= DBM:NewMod("Krystallus", "DBM-Party-WotLK", 7)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261026180406")
mod:SetCreatureID(27977)
mod:SetEncounterID(563)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"UNIT_SPELLCAST_SUCCEEDED"
)

local specWarningShatter	= mod:NewSpecialWarningMoveAway(50810, nil, nil, nil, 1, 2)
local timerGroundSlamCD		= mod:NewCDTimer(20, 50833, nil, nil, nil, 3)

mod:AddRangeFrameOption("20")

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == GetSpellInfo(50827) then  -- Ground Slam
		self:SendSync("GroundSlam")
	elseif spellName == GetSpellInfo(50810) then  -- Shatter
		self:SendSync("Shatter")
	end
end

function mod:OnSync(msg)
	if not self:IsInCombat() then return end
	if msg == "GroundSlam" then
		specWarningShatter:Show()
		specWarningShatter:Play("scatter")
		timerGroundSlamCD:Start()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(20)
		end
	elseif msg == "Shatter" then
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
