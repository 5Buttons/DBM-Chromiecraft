local mod	= DBM:NewMod("WolfMasterNandos", "DBM-Party-Classic", 14)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(3927)
mod:SetEncounterID(470)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 7487 7489"
)

local warningBleakWorg		= mod:NewSpellAnnounce(7487, 2)
local warningLupineHorror	= mod:NewSpellAnnounce(7489, 2)

local timerBleakWorgCD		= mod:NewCDTimer(75, 7487, nil, nil, nil, 1, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerLupineHorrorCD	= mod:NewCDTimer(25, 7489, nil, nil, nil, 1, nil, DBM_COMMON_L.DAMAGE_ICON)--Two 75s timers offset by 50s, so alternates 50/25

mod.vb.lupineCount = 0

function mod:OnCombatStart(delay)
	self.vb.lupineCount = 0
	timerBleakWorgCD:Start(30-delay)
	timerLupineHorrorCD:Start(5-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 7487 then
		warningBleakWorg:Show()
		timerBleakWorgCD:Start()
	elseif args.spellId == 7489 then
		self.vb.lupineCount = self.vb.lupineCount + 1
		warningLupineHorror:Show()
		timerLupineHorrorCD:Start(self.vb.lupineCount % 2 == 1 and 50 or 25)
	end
end
