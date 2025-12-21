local mod	= DBM:NewMod("SvalaSorrowgrave", "DBM-Party-WotLK", 11)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251221220131")
mod:SetCreatureID(29281)
mod:SetEncounterID(577)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 48278 48276",
	"SPELL_AURA_REMOVED 48278"
)

local warningSacrifice	= mod:NewTargetNoFilterAnnounce(48278, 4)

local timerSacrifice	= mod:NewBuffActiveTimer(25, 48278, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerRoleplay		= mod:NewTimer(67, "timerRoleplay", "Interface\\Icons\\Spell_Holy_BorrowedTime") --roleplay for boss is active

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 48278 then
		if self:AntiSpam(3, 1) then
			warningSacrifice:Show(args.destName)
		end
	elseif args.spellId == 48276 then
		timerSacrifice:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 48278 then
		timerSacrifice:Stop()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.SvalaRoleplayStart or msg:find(L.SvalaRoleplayStart) then
		timerRoleplay:Start()
	end
end
