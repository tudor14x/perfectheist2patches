local classname = "Gambler"

ListenToEvent("AbilityKeyPressed_OnClient", function(playerActor)
    if playerActor.CustomClassString == classname then
        if playerActor.ActionComponent.moneyAmount > 0 then
            if math.random(1,2) == 1 then
                playerActor:startAbilityCooldown(10)
            else
                playerActor:startAbilityCooldown(30)
            end
            PlaySound(playerActor, "GamblerScroll.mp3")
            playerActor:AbilitySV()
        end
    end
end)

ListenToEvent("AbilitySV", function(playerActor)
    if playerActor.CustomClassString == classname then
        if playerActor.ActionComponent.moneyAmount > 0 then
            SetTimer(3.5, "GamblerGamble", playerActor)
        end
    end
end)

ListenToEvent("GamblerGamble", function(playerActor)
    local coinflip = math.random(1,2)
    local jackpot = math.random(1,100)

    if jackpot == 1 then
        PlaySound(playerActor, "GamblerWin.mp3", 4)
        playerActor.ActionComponent.moneyAmount = playerActor.ActionComponent.moneyAmount*100
    else
        if coinflip == 1 then
            PlaySound(playerActor, "GamblerWin.mp3")
            playerActor.ActionComponent.moneyAmount = playerActor.ActionComponent.moneyAmount*2
        else  
            PlaySound(playerActor, "GamblerLose.mp3", 2.3)
            playerActor.ActionComponent.moneyAmount = playerActor.ActionComponent.moneyAmount / 2;
        end
    end
end)

ListenToEvent("PreReceiveDamage", function(target, source, damage)
    if source.CustomClassString == classname or target.CustomClassString == classname then
        local multi = math.random(1,7)/7

        target.HP = target.HP + (damage * multi)
    end
end)