local classname = "Chameleon"

-- 1. Ability activation (client)
ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
	if playerActor.CustomClassString == classname then
		playerActor:StartAbilityCooldown(30.0)  -- fixed: capital S
		playerActor:AbilitySV()
	end
end)

-- 2. Round end cleanup (client)
-- fixed: RoundEnded_OnClient -> RoundFinished_OnClient
ListenToEvent("RoundFinished_OnClient", function()
	for i, player in ipairs(GetPlayerChars()) do
		if player.CustomClassString == classname then
			player.Mesh:SetHiddenInGame(false)  -- fixed: capital G
		end
	end
end)

-- 3. Ability effect (server) - go invisible
ListenToEvent("AbilitySV", function(playerActor)
	if playerActor.CustomClassString == classname then
		playerActor.preventShooting = true
		playerActor.Mesh:SetHiddenInGame(true)  -- fixed: capital G
	end
end)

-- 4. Ability effect (ALL machines) - sound/effect when cloaking
-- FIXED: This was instantly unhiding the mesh. Use it for client-side FX instead.
ListenToEvent("AbilityALL_OnClient", function(playerActor)
	if playerActor.CustomClassString == classname then
		-- Example: PlaySound(playerActor, "CloakOn.wav", 1.0)
	end
end)

-- 5. Round tick - break invisibility if moving or rich (server)
ListenToEvent("RoundTick", function()
	for i, player in ipairs(GetPlayerChars()) do
		if player.CustomClassString == classname then
			local actionComp = player.ActionComponent
			local vel = player:GetVelocity()

			-- Defensive nil checks
			if actionComp and vel then
				local isMoving = (math.abs(vel.X) + math.abs(vel.Y)) > 0
				local isRich = actionComp.moneyAmount > 5000

				if isRich or isMoving then
					player.preventShooting = false
					player.Mesh:SetHiddenInGame(false)  -- fixed: capital G
				end
			end
		end
	end
end)

-- 6. Taking damage breaks cloak + slows time (server)
ListenToEvent("PreReceiveDamage", function(target, source, damage, damageType, canBeLethal)
	if target.CustomClassString == classname then
		-- Slow down time for 2 seconds
		if target.ActionComponent then
			target.ActionComponent:SlowDownTimeSV(1.5)
			SetTimer(2.0, "ChameleonSpeedStop", target)
		end

		-- Break cloak immediately
		target.preventShooting = false
		target.Mesh:SetHiddenInGame(false)  -- fixed: capital G
	end
end)

-- 7. Reset time dilation after 2 seconds
ListenToEvent("ChameleonSpeedStop", function(playerActor)
	if playerActor.ActionComponent then
		playerActor.ActionComponent:SlowDownTimeSV(1.0)
	end
end)