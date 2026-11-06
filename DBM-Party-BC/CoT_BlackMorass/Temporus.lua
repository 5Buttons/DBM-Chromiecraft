local mod	= DBM:NewMod(553, "DBM-Party-BC", 12, 255)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(17880, 21698)

mod:SetModelID(19066)
mod:SetModelOffset(0, 50, 0)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 31458 38592",
	"SPELL_AURA_REMOVED 31458",
	"UNIT_DIED"
)

local specWarnSpellReflect	= mod:NewSpecialWarningReflect(38592, nil, nil, 2, 1, 2)
local specWarnHasten		= mod:NewSpecialWarningDispel(31458, "MagicDispeller", nil, nil, 1, 2)

local timerSpellReflect		= mod:NewBuffActiveTimer(6, 38592, nil, nil, 2, 5, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerHasten			= mod:NewTargetTimer(10, 31458, nil, "MagicDispeller|Healer|Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON)

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 31458 and not args:IsDestTypePlayer() then
		specWarnHasten:Show(args.destName)
		specWarnHasten:Play("dispelboss")
		timerHasten:Start(args.destName)
	elseif args.spellId == 38592 then
		specWarnSpellReflect:Show(args.destName)
		specWarnSpellReflect:Play("stopattack")
		timerSpellReflect:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 31458 then
		timerHasten:Stop(args.destName)
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 17880 or cid == 21698 then--Only one of them is up per run
		DBM:EndCombat(self)
	end
end
