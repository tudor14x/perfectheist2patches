local classname = "Superhero"

local function addPos(pos1, pos2)
    return {
        X = pos1.X + pos2.X,
        Y = pos1.Y + pos2.Y,
        Z = pos1.Z + pos2.Z
    }
end

-- Helper: get horizontal direction away from source, scaled by strength
local function getKnockbackDir(targetLoc, sourceLoc, hStrength, zStrength)
    local dir = {
        X = targetLoc.X - sourceLoc.X,
        Y = targetLoc.Y - sourceLoc.Y,
        Z = 0
    }
    local len = math.sqrt(dir.X * dir.X + dir.Y * dir.Y)
    if len > 0 then
        dir.X = (dir.X / len) * hStrength
        dir.Y = (dir.Y / len) * hStrength
    end
    dir.Z = zStrength
    return dir
end

-- 1. Ability activation (client)
ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
    if playerActor.CustomClassString == classname then
        playerActor:StartAbilityCooldown(45.0)  -- fixed case
        playerActor:AbilitySV()
    end
end)

-- 2. Start laser (server)
ListenToEvent("AbilitySV", function(playerActor)
    if playerActor.CustomClassString == classname then
        AddActorTag(playerActor, "LaserBeam")
        playerActor:SetLocalVar("LaserFireReady", "true")
        SetTimer(5.0, "SuperheroEndLaser", playerActor)
    end
end)

-- 3. End laser
ListenToEvent("SuperheroEndLaser", function(playerActor)
    RemoveActorTag(playerActor, "LaserBeam")
    playerActor:SetLocalVar("LaserFireReady", nil)
end)

-- 4. Fire laser with rate-limiting (server)
ListenToEvent("RoundTick", function()
    for i, player in ipairs(GetPlayerChars()) do
        if ActorHasTag(player, "LaserBeam") then
            -- Only fire every 0.15 seconds instead of every frame
            if player:GetLocalVar("LaserFireReady") == "true" then
                player:SetLocalVar("LaserFireReady", "false")
                SetTimer(0.15, "SuperheroLaserFireReady", player)

                local startPos = player:GetActorLocation()
                local forward = player:GetActorForwardVector()
                forward.Z = player.PitchSV / 90
                local endPos = addPos(startPos, {
                    X = forward.X * 100000,
                    Y = forward.Y * 100000,
                    Z = forward.Z * 100000
                })

                local laser = LineMultiTrace(startPos, endPos, {player})

                -- ONLY process the first (closest) hit
                if #laser > 0 then
                    local hit = laser[1]
                    local hitClass = GetActorClassName(hit.Actor)

                    if hitClass == "SafeDoor" then
                        hit.Actor:Explode()
                    elseif hitClass ~= "MolotovPart" then
                        SpawnActor("MolotovPart", hit.Location)
                    end
                end
            end
        end
    end
end)

-- Re-enable fire spawning after cooldown
ListenToEvent("SuperheroLaserFireReady", function(playerActor)
    if ActorHasTag(playerActor, "LaserBeam") then
        playerActor:SetLocalVar("LaserFireReady", "true")
    end
end)

-- 5. One-tap punch + launch back (server)
ListenToEvent("PreReceiveDamage", function(targetActor, sourceActor, damage, damageType, canBeLethal)
    if not sourceActor then return end
    if sourceActor.CustomClassString ~= classname then return end

    -- damageType 2 = Melee Attack (fists)
    if damageType == 2 then
        -- Instakill
        targetActor.HP = 10 + targetActor.HP / 2;

        -- Launch them away
        local tLoc = targetActor:GetActorLocation()
        local sLoc = sourceActor:GetActorLocation()
        local launch = getKnockbackDir(tLoc, sLoc, 2500, 1200)

        -- bXYOverride=true, bZOverride=true replaces their current velocity cleanly
        targetActor:LaunchCharacter(launch, true, true)
    end
end)