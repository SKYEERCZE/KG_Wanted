-- client/threads/crime_detection.lua

KGW = KGW or {}
KGW.lastRunoverReport = KGW.lastRunoverReport or 0

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1

    if not victim or not attacker then return end
    if not DoesEntityExist(victim) or not DoesEntityExist(attacker) then return end
    if not IsEntityAPed(victim) then return end

    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    if victimPlayer == -1 then return end

    local victimSrc = GetPlayerServerId(victimPlayer)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local vCoords = GetEntityCoords(victim)
    local dist = #(myCoords - vCoords)

    -- KILL: attacker = tvoje ped
    if IsEntityAPed(attacker) then
        local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)
        if attackerPlayer == -1 then return end
        if attackerPlayer ~= PlayerId() then return end

        if victimDied then
            TriggerServerEvent('kg_wanted:crime', { type = 'kill', victim = victimSrc, dist = dist })
        end
        return
    end

    -- RUNOVER: attacker = vehicle který řídíš
    if IsEntityAVehicle(attacker) then
        local veh = attacker
        local driver = GetPedInVehicleSeat(veh, -1)
        if not driver or driver == 0 or not DoesEntityExist(driver) then return end
        if NetworkGetPlayerIndexFromPed(driver) ~= PlayerId() then return end

        local now = GetGameTimer()
        if now - (KGW.lastRunoverReport or 0) < 2500 then return end
        KGW.lastRunoverReport = now

        TriggerServerEvent('kg_wanted:crime', {
            type = 'runover',
            victim = victimSrc,
            dist = dist,
            died = victimDied
        })
        return
    end
end)
