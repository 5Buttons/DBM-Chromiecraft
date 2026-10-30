local mod	= DBM:NewMod("Vashj", "DBM-Serpentshrine")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030180000")
mod:SetCreatureID(21212)
mod:SetEncounterID(628)
--mod:SetModelID(20748)
mod:SetUsedIcons(1)
mod:SetHotfixNoticeRev(20210919000000)
mod:SetMinSyncRevision(20210919000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 38280 38575",
	"SPELL_AURA_REMOVED 38280 38112",
	"SPELL_CAST_START 38253",
	"SPELL_CAST_SUCCESS 38316 38509",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_LOOT"
)

local warnCharge		= mod:NewTargetNoFilterAnnounce(38280, 4)
local warnEntangle		= mod:NewSpellAnnounce(38316, 3)
local warnPhase2		= mod:NewPhaseAnnounce(2)
local warnElemental		= mod:NewAnnounce("WarnElemental", 4, 31687)
local warnStrider		= mod:NewAnnounce("WarnStrider", 3, 475)
local warnNaga			= mod:NewAnnounce("WarnNaga", 3, 2120)
local warnShield		= mod:NewAnnounce("WarnShield", 3, 38112)
local warnLoot			= mod:NewAnnounce("WarnLoot", 4, 38132)
local warnPhase3		= mod:NewPhaseAnnounce(3)

--local specWarnCore		= mod:NewSpecialWarning("SpecWarnCore", nil, nil, nil, 1, 8)
local specWarnCharge	= mod:NewSpecialWarningMoveAway(38280, nil, nil, nil, 1, 2)
local yellCharge		= mod:NewYell(38280)
local specWarnElemental	= mod:NewSpecialWarning("SpecWarnElemental")--Changed from soon to a now warning. the soon warning not accurate because of 11 second variation so not useful special warning.
local specWarnToxic		= mod:NewSpecialWarningMove(38575, nil, nil, nil, 1, 2)

local timerEntangleCD	= mod:NewCDTimer("v18.2-51.5", 38316, nil, nil, nil, 3, nil, nil, true)
local timerCharge		= mod:NewTargetTimer(20, 38280, nil, nil, nil, 3)
local timerChargeCD		= mod:NewCDTimer("v7.25-27.05", 38280, nil, nil, nil, 3, nil, nil, true)
local timerShockBlastCD	= mod:NewCDTimer("v10.85-25.1", 38509, nil, nil, nil, 3, nil, nil, true)
local timerElemental	= mod:NewTimer(13, "TimerElementalActive", 39088, nil, nil, 1)
local timerElementalCD	= mod:NewTimer(50, "TimerElemental", 39088, nil, nil, 1)
local timerStrider		= mod:NewTimer(60, "TimerStrider", 475, nil, nil, 1)
local timerNaga			= mod:NewTimer(45, "TimerNaga", 2120, nil, nil, 1)

mod:AddRangeFrameOption(10, 38280)
mod:AddSetIconOption("ChargeIcon", 38280, false, false, {1})

mod.vb.shieldLeft = 4
mod.vb.nagaCount = 1
mod.vb.striderCount = 1
mod.vb.elementalCount = 1
local elementals = {}

local function StriderSpawn(self)
	self.vb.striderCount = self.vb.striderCount + 1
	warnStrider:Schedule(55, tostring(self.vb.striderCount))
	timerStrider:Start(nil, tostring(self.vb.striderCount))
	self:Schedule(60, StriderSpawn, self)
end

local function NagaSpawn(self)
	self.vb.nagaCount = self.vb.nagaCount + 1
	warnNaga:Schedule(40, tostring(self.vb.nagaCount))
	timerNaga:Start(nil, tostring(self.vb.nagaCount))
	self:Schedule(45, NagaSpawn, self)
end

function mod:OnCombatStart(delay)
	table.wipe(elementals)
	self:SetStage(1)
	self.vb.shieldLeft = 4
	self.vb.nagaCount = 1
	self.vb.striderCount = 1
	self.vb.elementalCount = 1
	timerEntangleCD:Start(25.45-delay)
	timerChargeCD:Start(18.15-delay)
	timerShockBlastCD:Start(14.55-delay)
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 38280 then
		timerCharge:Start(args.destName)
		timerChargeCD:Start()
		if args:IsPlayer() then
			specWarnCharge:Show()
			specWarnCharge:Play("runout")
			yellCharge:Yell()
			if self.Options.RangeFrame then
				DBM.RangeCheck:Show(10)
			end
		else
			warnCharge:Show(args.destName)
		end
		if self.Options.ChargeIcon then
			self:SetIcon(args.destName, 1, 20)
		end
	elseif spellId == 38575 and args:IsPlayer() and self:AntiSpam() then
		specWarnToxic:Show()
		specWarnToxic:Play("runaway")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 38280 then
		timerCharge:Stop(args.destName)
		if self.Options.ChargeIcon then
			self:SetIcon(args.destName, 0)
		end
		if args:IsPlayer() then
			if self.Options.RangeFrame then
				DBM.RangeCheck:Hide()
			end
		end
	elseif spellId == 38112 then
		DBM:AddMsg("Magic Barrier unhidden from combat log. Notify Fivebuttons on Discord or GitHub")
		self.vb.shieldLeft = self.vb.shieldLeft - 1
		warnShield:Show(self.vb.shieldLeft)
	end
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 38253 and not elementals[args.sourceGUID] then
		specWarnElemental:Show()
		timerElemental:Start()
		elementals[args.sourceGUID] = true
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 38316 then
		timerEntangleCD:Start()
		warnEntangle:Show()
	elseif spellId == 38509 then
		timerShockBlastCD:Start()
	end
end

local function ElementalSpawn(self)
	self.vb.elementalCount = self.vb.elementalCount + 1
	warnElemental:Schedule(45, tostring(self.vb.elementalCount))
	timerElementalCD:Start(nil, tostring(self.vb.elementalCount))
	self:Schedule(50, ElementalSpawn, self)
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.DBM_VASHJ_YELL_PHASE2 or msg:find(L.DBM_VASHJ_YELL_PHASE2) then
		self:SetStage(2)
		self.vb.nagaCount = 1
		self.vb.striderCount = 1
		self.vb.elementalCount = 1
		self.vb.shieldLeft = 4
		warnPhase2:Show()
		timerChargeCD:Cancel()
		timerEntangleCD:Cancel()
		timerShockBlastCD:Cancel()

		timerNaga:Start(nil, tostring(self.vb.nagaCount))
		warnNaga:Schedule(40, tostring(self.vb.nagaCount))
		self:Schedule(45, NagaSpawn, self)

		timerElementalCD:Start(nil, tostring(self.vb.elementalCount))
		warnElemental:Schedule(45, tostring(self.vb.elementalCount))
		self:Schedule(50, ElementalSpawn, self)

		timerStrider:Start(nil, tostring(self.vb.striderCount))
		warnStrider:Schedule(55, tostring(self.vb.striderCount))
		self:Schedule(60, StriderSpawn, self)
	elseif msg == L.DBM_VASHJ_YELL_PHASE3 or msg:find(L.DBM_VASHJ_YELL_PHASE3) then
		self:SetStage(3)
		warnPhase3:Show()
		timerNaga:Cancel()
		warnNaga:Cancel()
		timerElementalCD:Cancel()
		warnElemental:Cancel()
		timerStrider:Cancel()
		warnStrider:Cancel()
		self:Unschedule(NagaSpawn)
		self:Unschedule(StriderSpawn)
		self:Unschedule(ElementalSpawn)
			timerChargeCD:Start(18.15)
		timerEntangleCD:Start(25.45)
		timerShockBlastCD:Start(14.55)
	end
end

function mod:CHAT_MSG_LOOT(msg)
	-- DBM:AddMsg(msg) --> Meridium receives loot: [Magnetic Core]
	local player, itemID = msg:match(L.LootMsg)
	if player and itemID and tonumber(itemID) == 31088 and self:IsInCombat() then
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
--			if playerName == UnitName("player") then
--				specWarnCore:Show()
--				specWarnCore:Play("useitem")
--			else
				warnLoot:Show(playerName)
--			end
		end
	end
end
