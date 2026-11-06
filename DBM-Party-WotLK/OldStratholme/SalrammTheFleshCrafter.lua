local mod	= DBM:NewMod("SalrammTheFleshcrafter", "DBM-Party-WotLK", 3)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(26530)
mod:SetEncounterID(294)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 58845 52708",
	"SPELL_AURA_REMOVED 58845",
	"SPELL_SUMMON 52451"
)

local warningCurse	= mod:NewTargetNoFilterAnnounce(58845, 2, nil, "RemoveCurse", 2)
local warningSteal	= mod:NewTargetNoFilterAnnounce(52708, 2)
local warningGhoul	= mod:NewSpellAnnounce(52451, 3)

local timerGhoulCD	= mod:NewCDTimer(10, 52451, nil, nil, nil, 1)
local timerCurse	= mod:NewTargetTimer(30, 58845, nil, "RemoveCurse", nil, 5, nil, DBM_COMMON_L.CURSE_ICON)

function mod:OnCombatStart(delay)
	timerGhoulCD:Start(16-delay)
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 52451 then
		warningGhoul:Show()
		timerGhoulCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 58845 then
		warningCurse:Show(args.destName)
		timerCurse:Start(args.destName)
	elseif args.spellId == 52708 then -- AC: Steal Flesh channel aura on victim (52711 debuff follows on removal)
		warningSteal:Show(args.destName)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 58845 then
		timerCurse:Cancel(args.destName)
	end
end
