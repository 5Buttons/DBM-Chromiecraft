local mod	= DBM:NewMod("SkadiTheRuthless", "DBM-Party-WotLK", 11)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251123220131")
mod:SetCreatureID(26693)
mod:SetEncounterID(581)
mod:SetMinSyncRevision(3108)

mod:RegisterCombat("yell", L.Phase2)

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 50255 59331",
	"SPELL_AURA_APPLIED 50258 59334 50228 59322",
	"SPELL_AURA_REMOVED 50258 59334",
	"CHAT_MSG_TRADESKILLS"
)

local warnPhase2			= mod:NewPhaseAnnounce(2)
local warningPoisonDebuff	= mod:NewTargetNoFilterAnnounce(50258, 2, nil, "Healer")

local specWarnWhirlwind		= mod:NewSpecialWarningRun(59322, nil, nil, 2, 4, 2)
local warnHarpoonLoot		= mod:NewAnnounce("WarnLoot", 4, 44053)

local timerPoisonDebuff		= mod:NewTargetTimer(12, 50258, nil, "Healer", 2, 5, nil, DBM_COMMON_L.HEALER_ICON)
local timerPoisonCD			= mod:NewCDTimer(10, 59331, nil, "Healer", nil, 5)
local timerWhirlwindCD		= mod:NewCDTimer(20, 59322, nil, nil, nil, 2)
local timerAchieve			= mod:NewAchievementTimer(180, 1873)

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(50255, 59331) then
		timerPoisonCD:Start() -- Poisoned Spear throw
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(50258, 59334) then
		warningPoisonDebuff:Show(args.destName)
		timerPoisonDebuff:Start(args.destName)
	elseif args:IsSpellID(50228, 59322) then
		timerWhirlwindCD:Start()
		specWarnWhirlwind:Show()
		specWarnWhirlwind:Play("runout")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(50258, 59334) then
		timerPoisonDebuff:Cancel(args.destName)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Phase2 or msg:find(L.Phase2) then
		warnPhase2:Show()
	elseif msg == L.CombatStart or msg:find(L.CombatStart) then
		if not self:IsDifficulty("normal5") then
			timerAchieve:Start()
		end
	end
end

function mod:CHAT_MSG_TRADESKILLS(msg) --copied from Najentus/Vashj
	local player = msg:match(L.LootMsg)
	if player and self:IsInCombat() then
		-- attempt to correct player name when the player is the one looting
		if DBM:GetGroupId(player) == 0 then -- workaround to determine that player doesn't exist in our group
			if player == DBM_COMMON_L.YOU then -- LOOT_ITEM_SELF = "You receive loot: %s." Not useable in all locales since there is no pronoun or not translateable "YOU" (ES: Recibes botín: %s.")
				player = UnitName("player") -- convert localized "You" to player name
			else -- logically is more prone to be innacurate, but do it anyway to account for the locales without a useable YOU and prevent UNKNOWN player name on sync handler
				player = UnitName("player")
			end
		end
		self:SendSync("LootMsg", player)
	end
end

function mod:OnSync(event, playerName)
	if not self:IsInCombat() then return end
	if event == "LootMsg" and playerName then
		playerName = DBM:GetUnitFullName(playerName)
		if self:AntiSpam(2, playerName) then
			warnHarpoonLoot:Show(playerName)
		end
	end
end