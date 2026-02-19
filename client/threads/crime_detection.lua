-- client/threads/crime_detection.lua
-- Detect: kill player + run over player (no fist/hurt wanted)

CreateThread(function()
    KGW = KGW or {}
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1

    if not victim or not attacker then return end
    if not DoesEntityExist(victim) or not DoesEntityExist(attacker) then return end
    if not IsEntityAPed(victim) then return end

    -- Only care about PLAYER victims
    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    if victimPlayer == -1 then return end

    local victimSrc = GetPlayerServerId(victimPlayer)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local vCoords = GetEntityCoords(victim)
    local dist = #(myCoords - vCoords)

    -- A) Attacker is a PED (player kill)
    if IsEntityAPed(attacker) then
        local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)
        if attackerPlayer == -1 then return end
        if attackerPlayer ~= PlayerId() then return end

        -- ✅ only KILL counts
        if victimDied then
            TriggerServerEvent('kg_wanted:crime', {
                type = 'kill',
                victim = victimSrc,
                dist = dist
            })
        end
        return
    end

    -- B) Attacker is a VEHICLE (runover)
    if IsEntityAVehicle(attacker) then
        local veh = attacker
        local driver = GetPedInVehicleSeat(veh, -1)
        if not driver or driver == 0 or not DoesEntityExist(driver) then return end
        if NetworkGetPlayerIndexFromPed(driver) ~= PlayerId() then return end

        -- cooldown so it doesn't spam every tick
        local now = GetGameTimer()
        if (KGW.lastRunoverReport or 0) + 2500 > now then return end
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
