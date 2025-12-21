local mod	= DBM:NewMod("Keristrasza", "DBM-Party-WotLK", 8)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251221220131")
mod:SetCreatureID(26723)
mod:SetEncounterID(526)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 50997 8599 48179",
	"SPELL_AURA_REMOVED 50997",
	"SPELL_AURA_APPLIED 48095",
	"SPELL_AURA_APPLIED_DOSE 48095"
)

local warningChains		= mod:NewTargetNoFilterAnnounce(50997, 4)
local warningNova		= mod:NewSpellAnnounce(48179, 3)
local warningEnrage		= mod:NewSpellAnnounce(8599, 3, nil, "Tank|Healer", 2)

local specWarnIntenseCold	= mod:NewSpecialWarningStack(48095, nil, 4, nil, nil, 1, 6)


local timerChains		= mod:NewTargetTimer(10, 50997, nil, "Healer", 2, 5, nil, DBM_COMMON_L.HEALER_ICON..DBM_COMMON_L.MAGIC_ICON)
local timerChainsCD		= mod:NewCDTimer(20, 50997, nil, nil, nil, 3)
local timerNova			= mod:NewBuffActiveTimer(10, 48179)
local timerNovaCD		= mod:NewCDTimer(11, 48179, nil, nil, nil, 2)

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 50997 then
		warningChains:Show(args.destName)
		timerChains:Start(args.destName)
		if mod:IsHeroic() then
			timerChainsCD:Start(11)
		else
			timerChainsCD:Start(20)
		end
	elseif args.spellId == 8599 and args.sourceGUID == 26723 then
		warningEnrage:Show()
	elseif args.spellId == 48179 then
		warningNova:Show()
		timerNova:Start()
		timerNovaCD:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 50997 then
		timerChains:Cancel()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 48095 then		-- Intense Cold
		local amount = args.amount or 1
		if amount >= 4 then
			if args:IsPlayer() then
				specWarnIntenseCold:Show(args.amount)
				specWarnIntenseCold:Play("movesoon")
			end
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED