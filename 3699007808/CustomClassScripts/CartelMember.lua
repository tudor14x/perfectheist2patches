local classname = "CartelMember"
local MAX_CARTEL = 10
local DEFAULT_CARTEL = 2
local ABILITY_COOLDOWN = 1.0
local RECRUIT_RADIUS = 400
local DEATH_REPLENISH_TIME = 30.0
local RECRUIT_COST = 9000

-- Tracks which player owns each cartel member (key = actor name, value = owner player name)
local CartelOwners = {}

-- Helper: safely get a player's cartel counter
local function GetCartelCount(playerActor)
	local count = tonumber(playerActor:GetReplicatedVar("CartelCount"))
	if count == nil then
		count = MAX_CARTEL
		playerActor:SetReplicatedVar("CartelCount", tostring(count))
	end
	return count
end

-- Helper: safely set a player's cartel counter (clamped 0-MAX)
local function SetCartelCount(playerActor, count)
	if count > MAX_CARTEL then count = MAX_CARTEL end
	if count < 0 then count = 0 end
	playerActor:SetReplicatedVar("CartelCount", tostring(count))
end

-- Helper: find a player actor by their PlayersName
local function FindPlayerByName(name)
	local players = GetPlayerChars()
	for i, p in ipairs(players) do
		if p.PlayersName == name then
			return p
		end
	end
	return nil
end

-- Reset everyone's counter to DEFAULT_CARTEL at the start of each round
ListenToEvent("RoundStarted", function()
	local players = GetPlayerChars()
	for i, p in ipairs(players) do
		if p.CustomClassString == classname then
			SetCartelCount(p, DEFAULT_CARTEL)
		end
	end
end)

-- OPEN PIE MENU
ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
	if playerActor.CustomClassString ~= classname then
		return
	end

	StartPieMenu(playerActor, {
		{
			Name = "RecruitGGGGGGGGGGG",
			Description = "Recruit a nearby NPC ($9,000)",
			Icon = "cartelcorrupt.png"
		},
		{
			Name = "Backup",
			Description = "Spawn a cartel member",
			Icon = "cartelbackup.png"
		}
	})
end)

-- SELECTED
ListenToEvent("PieMenuSelected_OnClient", function(playerActor, selectedIndex)
	if playerActor.CustomClassString ~= classname then
		return
	end
	playerActor:SetReplicatedVar("AbilityUseType", tostring(selectedIndex))
	playerActor:AbilitySV()
end)

-- SERVER: handle whichever pie option was chosen
ListenToEvent("AbilitySV", function(playerActor)
	if playerActor.CustomClassString ~= classname then
		return
	end

	local useType = tonumber(playerActor:GetReplicatedVar("AbilityUseType"))

	-----------------------------------------------------------------
	-- 0 = RECRUIT  (convert a nearby NPC into a cartel member)
	-----------------------------------------------------------------
	if useType == 0 then
		local money = 0
		if playerActor.ActionComponent then
			money = tonumber(playerActor.ActionComponent.moneyAmount) or 0
		end

		if money < RECRUIT_COST then
			-- Not enough cash — optionally show a client-side hint here
			return
		end

		if GetCartelCount(playerActor)+1 > MAX_CARTEL then return end

		local plrpos = playerActor:GetActorLocation()
		local nearby = SphereOverlap(plrpos, RECRUIT_RADIUS)
		local targetActor = nil

		for i, actor in ipairs(nearby) do
			if actor ~= playerActor and not ActorHasTag(actor, "CartelMember") then
				local className = GetActorClassName(actor)
				-- Target AI pawns (civilians, cops, guards, etc.) that aren't real players
				if className and (className:find("AI") or className:find("Civilian") or className:find("Guard")) then
					if not actor.PlayersName or actor.PlayersName == "" then
						targetActor = actor
						break
					end
				end
			end
		end

		if targetActor then
			-- Deduct the cash
			playerActor.ActionComponent.moneyAmount = money - RECRUIT_COST
			SetCartelCount(playerActor, GetCartelCount(playerActor)+1)
			local gs = GetGameState()
			gs:LuaDestroyActor(targetActor)
		end

	-----------------------------------------------------------------
	-- 1 = BACKUP  (spawn from your cartel counter)
	-----------------------------------------------------------------
	elseif useType == 1 then
		local count = GetCartelCount(playerActor)
		if count <= 0 then
			return
		end

		SetCartelCount(playerActor, count - 1)

		PlaySound(playerActor, "cartelspawn.mp3", 0.3)
		local plrpos = playerActor:GetActorLocation()
		local forward = playerActor:GetActorForwardVector()
		local behindPos = {
			X = plrpos.X - forward.X * 50,
			Y = plrpos.Y - forward.Y * 50,
			Z = plrpos.Z - forward.Z * 50
		}

		local npc = SpawnActor("PlayerAI_Rob", behindPos)
		npc.difficulty = 1
		AddActorTag(npc, "CartelMember")

		local npcName = GetActorName(npc)
		CartelOwners[npcName] = playerActor.PlayersName
	end
end)

-- PASSIVE: killing a cop grants +1 to the counter (capped at MAX_CARTEL)
ListenToEvent("PreReceiveDamage", function(target, source, damage, damageType, canBeLethal)
	if source and target then
		if target.HP - damage <= 0 then
			if source.CustomClassString == classname and target.PlayersName then
				local count = GetCartelCount(source)
				if count < MAX_CARTEL then
					SetCartelCount(source, count + 1)
				end
			elseif ActorHasTag(target, "CartelMember") then
				local destroyedName = GetActorName(target)
				local ownerName = CartelOwners[destroyedName]
				if ownerName then
					local owner = FindPlayerByName(ownerName)
					if owner then
						SetTimer(DEATH_REPLENISH_TIME, "CartelMemberDied", owner, destroyedName)
					end
					CartelOwners[destroyedName] = nil
					local gs = GetGameState()
					gs:LuaDestroyActor(target)
				end
			end
		end
	end
end)

-- Replenish counter 30 seconds after a cartel member dies
ListenToEvent("CartelMemberDied", function(ownerPlayer, destroyedName)
	if ownerPlayer and ownerPlayer.CustomClassString == classname then
		local count = GetCartelCount(ownerPlayer)
		if count < MAX_CARTEL then
			SetCartelCount(ownerPlayer, count + 1)
		end
	end
end)

-- Detect when a cartel member is destroyed and start the 30s replenish timer
ListenToEvent("AnyActorDestroyed", function(destroyedActor)
	if ActorHasTag(destroyedActor, "CartelMember") then
		local destroyedName = GetActorName(destroyedActor)
		local ownerName = CartelOwners[destroyedName]
		if ownerName then
			local owner = FindPlayerByName(ownerName)
			if owner then
				SetTimer(DEATH_REPLENISH_TIME, "CartelMemberDied", owner)
			end
			CartelOwners[destroyedName] = nil -- clean up
		end
	end
end)

-- CLIENT UI: show current cartel counter on screen
local uiFrame = 0
ListenToEvent("RoundTick_OnClient", function()
	uiFrame = uiFrame + 1
	if uiFrame % 30 ~= 0 then return end -- update roughly every 0.5s

	local player = GetPlayerPawn()
	if player and player.CustomClassString == classname then
		local count = GetCartelCount(player)
		ShowUIText("CartelCounter", "Cartel Members: " .. count .. "/" .. MAX_CARTEL,
			0.5, 0.88, 0, 20, {R=1, G=0.8, B=0, A=1})
	end
end)