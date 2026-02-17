KGW = KGW or {}

local lastHurtReport = 0

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1

    if not victim or not attacker then return end
    if not DoesEntityExist(victim) or not DoesEntityExist(attacker) then return end
    if not IsEntityAPed(victim) or not IsEntityAPed(attacker) then return end

    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)

    if victimPlayer == -1 or attackerPlayer == -1 then return end
    if attackerPlayer ~= PlayerId() then return end

    local victimSrc = GetPlayerServerId(victimPlayer)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local vCoords = GetEntityCoords(victim)
    local dist = #(myCoords - vCoords)

    if victimDied then
        TriggerServerEvent(KGW.Const.Events.Crime, { type = 'kill', victim = victimSrc, dist = dist })
    else
        local now = GetGameTimer()
        if now - lastHurtReport > 5000 then
            lastHurtReport = now
            TriggerServerEvent(KGW.Const.Events.Crime, { type = 'hurt', victim = victimSrc, dist = dist })
        end
    end
end)
