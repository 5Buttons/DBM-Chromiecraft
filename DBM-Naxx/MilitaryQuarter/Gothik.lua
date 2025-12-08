local mod	= DBM:NewMod("Gothik", "DBM-Naxx", 4)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251204210600")
mod:SetCreatureID(16060)
mod:SetEncounterID(1109)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_DIED"
)

--TODO, sync infoframe from classic era version?
--(source.type = "NPC" and source.firstSeen = timestamp) or (target.type = "NPC" and target.firstSeen = timestamp)
local warnWaveNow		= mod:NewAnnounce("WarningWaveSpawned", 3, nil, false)
local warnWaveSoon		= mod:NewAnnounce("WarningWaveSoon", 2)
local warnRiderDown		= mod:NewAnnounce("WarningRiderDown", 4)
local warnKnightDown	= mod:NewAnnounce("WarningKnightDown", 2)
local warnGateOpen		= mod:NewSpellAnnounce(3366, 2)
local warnPhase2		= mod:NewPhaseAnnounce(2, 3)

local timerPhase2		= mod:NewTimer(270, "TimerPhase2", 27082, nil, nil, 6)
local timerWave			= mod:NewTimer(20, "TimerWave", 5502, nil, nil, 1)
local timerGate			= mod:NewTimer(120, "Gate Opens", 9484)

mod.vb.wave = 0
local wavesNormal = {
	{2, L.Trainee, timer = 20},     -- Wave 1: 20s
	{2, L.Trainee, timer = 20},     -- Wave 2: 20s
	{2, L.Trainee, timer = 10},     -- Wave 3: 10s
	{1, L.Knight, timer = 10},      -- Wave 4: 10s
	{2, L.Trainee, timer = 15},     -- Wave 5: 15s
	{1, L.Knight, timer = 10},      -- Wave 6: 10s
	{2, L.Trainee, timer = 15},     -- Wave 7: 15s
	{1, L.Knight, 2, L.Trainee, timer = 10},
	{1, L.Rider, timer = 10},       -- Wave 10: 10s
	{2, L.Trainee, timer = 5},      -- Wave 11: 5s
	{1, L.Knight, timer = 15},      -- Wave 12: 15s
	{2, L.Trainee, 1, L.Rider, timer = 10},
	{1, L.Knight, timer = 10},      -- Wave 15: 10s
	{2, L.Trainee, timer = 10},     -- Wave 16: 10s
	{1, L.Rider, timer = 5},        -- Wave 17: 5s
	{1, L.Knight, timer = 5},       -- Wave 18: 5s
	{2, L.Trainee, timer = 20},     -- Wave 19: 20s
	{1, L.Rider, 1, L.Knight, 2, L.Trainee, timer = 15},
	{2, L.Trainee},     -- Wave 23: 29s (final wave)
}
local wavesHeroic = {
	{3, L.Trainee, timer = 20},
	{3, L.Trainee, timer = 20},
	{3, L.Trainee, timer = 10},
	{2, L.Knight, timer = 10},
	{3, L.Trainee, timer = 15},
	{2, L.Knight, timer = 5},
	{3, L.Trainee, timer = 20},
	{3, L.Trainee, 2, L.Knight, timer = 10},
	{3, L.Trainee, timer = 10},
	{1, L.Rider, timer = 5},
	{3, L.Trainee, timer = 15},
	{1, L.Rider, timer = 10},
	{2, L.Knight, timer = 10},
	{1, L.Rider, timer = 10},
	{1, L.Rider, 3, L.Trainee, timer = 5},
	{1, L.Knight, 3, L.Trainee, timer = 5},
	{1, L.Rider, 3, L.Trainee, timer = 20},
	{1, L.Rider, 2, L.Knight, 3, L.Trainee},
}

local waves = wavesNormal

local function StartPhase2(self)
	self:SetStage(2)
	warnPhase2:Show()
end

local function getWaveString(wave)
	local waveInfo = waves[wave]
	if #waveInfo == 2 then
		return L.WarningWave1:format(unpack(waveInfo))
	elseif #waveInfo == 4 then
		return L.WarningWave2:format(unpack(waveInfo))
	elseif #waveInfo == 6 then
		return L.WarningWave3:format(unpack(waveInfo))
	end
end

local function NextWave(self)
	self.vb.wave = self.vb.wave + 1
	warnWaveNow:Show(self.vb.wave, getWaveString(self.vb.wave))
	local timer = waves[self.vb.wave].timer
	if timer and timer > 0 then
		timerWave:Start(timer, self.vb.wave + 1)
		warnWaveSoon:Schedule(timer - 3, self.vb.wave + 1, getWaveString(self.vb.wave + 1))
		self:Schedule(timer, NextWave, self)
	elseif timer == 0 then
		-- Immediate next wave
		self:Schedule(0.1, NextWave, self)
	end
end

function mod:OnCombatStart()
	self:SetStage(1)
	if self:IsDifficulty("normal25") then
		waves = wavesHeroic
	else
		waves = wavesNormal
	end
	self.vb.wave = 0
	timerGate:Start()
	timerPhase2:Start()
	warnPhase2:Schedule(270)
	timerWave:Start(30, self.vb.wave + 1)
	warnWaveSoon:Schedule(27, self.vb.wave + 1, getWaveString(self.vb.wave + 1))
	self:Schedule(30, NextWave, self)
	self:Schedule(270, StartPhase2, self)
end

function mod:OnTimerRecovery()
	if self:IsDifficulty("normal25") then
		waves = wavesHeroic
	else
		waves = wavesNormal
	end
end

--[[function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.GothikPhase2Yell or msg:find(L.GothikPhase2Yell) then
		StartPhase2(self)
	end
end]]

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.GothikDoorEmote or msg:find(L.GothikDoorEmote) then
		DBM:AddSpecialEventToTranscriptorLog("Gothik Door Opened")
		warnGateOpen:Show()
	end
end

function mod:UNIT_DIED(args)
	if bit.band(args.destGUID:sub(0, 5), 0x00F) == 3 then
		local cid = self:GetCIDFromGUID(args.destGUID)
		if cid == 16126 then -- Unrelenting Rider
			warnRiderDown:Show()
		elseif cid == 16125 then -- Unrelenting Deathknight
			warnKnightDown:Show()
		end
	end
end
