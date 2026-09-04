local classname = "Disguiser"
local clothing = {"Customer_Hoodie_Red","Customer_Jacket_Green","Customer_Hoodie_Black","Customer_Jacket_Red","","","","","","Employee_PurpleTie","Employee_RedTie","","","","","","","","Cook"}
local zones = {{1,4},{10,11},{12,12},{20,20}}

local function GetDistance(actor1, actor2)
    local a = actor1:GetActorLocation()
    local b = actor2:GetActorLocation()
    local dx, dy, dz = a.X-b.X, a.Y-b.Y, a.Z-b.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

ListenToEvent("RoundStarted", function()
    local players = GetPlayerChars()
    for i, player in ipairs(players) do
        if player.CustomClassString == classname then
            SetTimer(1.0, "DisguiserPassive", player)
        end
    end
end)

ListenToEvent("DisguiserPassive", function(playerActor)
	if playerActor.HP < 100 then
		playerActor.HP = playerActor.HP + 1
	end
    SetTimer(1.0, "DisguiserPassive", playerActor)
end)

ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
	if playerActor.CustomClassString == classname then
		playerActor:startAbilityCooldown(30.0)
		
		playerActor:AbilitySV()
	end
end)

ListenToEvent("AbilitySV", function(playerActor)
	if playerActor.CustomClassString == classname then
		local plrpos = playerActor:GetActorLocation()
		local closestcustomer = GetClosestActor("AI_Customer", plrpos)
		local closestemployee = GetClosestActor("AI_Employee", plrpos)
		local closestcook = GetClosestActor("AI_KitchenStaff", plrpos)
		local closest = closestcustomer
			
		if closestcustomer and closestemployee then
			if GetDistance(playerActor, closestemployee) < GetDistance(playerActor, closestcustomer) then
				closest = closestemployee
				if closestemployee and closestcook then
					if GetDistance(playerActor, closestcook) < GetDistance(playerActor, closestemployee) then
						closest = closestcook
					end
				end
			end
		end
		
		if closest then
			local zone = playerActor.CurrentZone

			playerActor.ActionComponent:DropMoneyBagSV({X=0,Y=0,Z=0})
			playerActor.ActionComponent:DropBombBagSV({X=0,Y=0,Z=0})
			PlaySound(playerActor, "disguiservanish.mp3")
			playerActor:SetActorLocation(closest:GetActorLocation())
			closest:SetActorLocation(plrpos)
			playerActor:SetClothesSV(clothing[closest.ClothingID])
			closest.ClothingID_StartIncl = zones[zone+1][1]
			closest.ClothingID_EndIncl = zones[zone+1][2]
			closest:SetClothingID(true)
		end
	end
end)