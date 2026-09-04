local classname = "ArmsMaster"

local KILLSTREAK_MAX = 16
local ABILITY_COOLDOWN = 5.0
local ABILITY_PRICE = 4500

-- must be lower than or equal to 1
local DAMAGE_REDUCTION_PERCENTAGE_MAX = (70/100)

-- must be bigger than 0
local MOVESPEED_MULTIPLIER_MAX = 2

function getKillStreak(player)
	return tonumber(player:GetReplicatedVar("KillStreak"))
end

function getBoughtKillStreak(player)
	return tonumber(player:GetReplicatedVar("BoughtKillStreak"))
end

function getTotalKillStreaks(player)
	return getKillStreak(player) + getBoughtKillStreak(player)
end

ListenToEvent("RoundStarted", function()
	for i, player in ipairs(GetPlayerChars()) do
		if player.CustomClassString == classname then
			player:SetReplicatedVar("KillStreak", "0")
			player:SetReplicatedVar("BoughtKillStreak", "0")
		end
	end
end)

ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
	if playerActor.CustomClassString == classname then
		playerActor:AbilitySV()
	end
end)

ListenToEvent("AbilitySV", function(playerActor)
	if playerActor.CustomClassString == classname then
		local canAfford = (math.floor(playerActor.ActionComponent.MoneyAmount) >= ABILITY_PRICE)
		if not canAfford then return end
		if (getTotalKillStreaks(playerActor) + 1) > KILLSTREAK_MAX then
			return
		end
		playerActor:startAbilityCooldown(ABILITY_COOLDOWN)
		playerActor.ActionComponent.MoneyAmount = playerActor.ActionComponent.MoneyAmount - ABILITY_PRICE
		playerActor:SetReplicatedVar("BoughtKillStreak", tostring(tonumber(playerActor:GetReplicatedVar("BoughtKillStreak")) + 1))
	end
end)

ListenToEvent("RoundTick", function()
	for i, player in ipairs(GetPlayerChars()) do
		if player.CustomClassString == classname then
			local val = 1 + (( getTotalKillStreaks(player)/(KILLSTREAK_MAX*2) ))
			player.ActionComponent:SlowDownTimeSV(math.min(MOVESPEED_MULTIPLIER_MAX, val))
		end
	end
end)

ListenToEvent("PreReceiveDamage", function(target, source, damage)
	if target.PlayersName and source.PlayersName then
		if source then
			if source.CustomClassString == classname then
				local ks = getTotalKillStreaks(source)
				target.HP = target.HP - (ks / (KILLSTREAK_MAX/2)) * damage
				if target.HP - damage <= 0 then
					if (tonumber(source:GetReplicatedVar("KillStreak"))+1) <= KILLSTREAK_MAX then
						source:SetReplicatedVar("KillStreak", tostring(tonumber(source:GetReplicatedVar("KillStreak")) + 1))
					end
				end
			end
		end
		if target.CustomClassString == classname then
			local ks = getKillStreak(target)
			local multiplier = math.min((ks / KILLSTREAK_MAX), DAMAGE_REDUCTION_PERCENTAGE_MAX)
			target.HP = target.HP + multiplier * damage
			if target.HP - damage <= 0 then
				target:SetReplicatedVar("KillStreak", "0")
			end
		end
	end
end)