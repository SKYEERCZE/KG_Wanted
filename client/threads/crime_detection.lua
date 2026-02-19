-- KG_Wanted/client/threads/crime_detection.lua
-- Robust:
--  - kill: baseevents (primary) + entityDamage fallback
--  - runover: entityDamage weapon hash
--  - no hurt/punch wanted (unless kill)

KGW = KGW or {}
KGW.lastRunoverReport = KGW.lastRunoverReport or 0
KGW.lastVictimServerId = KGW.lastVictimServerId or 0
KGW.lastVictimDist = KGW.lastVictimDist or 0.0
KGW.lastAttackerWasMe = false

local WEAPON_RUN_OVER_BY_CAR = GetHashKey('WEAPON_RUN_OVER_BY_CAR')
local WEAPON_RAMMED_BY_CAR   = GetHashKey('WEAPON_RAMMED_BY_CAR')

local function sendCrime(payload)
    if type(payload) ~= 'table' then return end
    TriggerServerEvent('kg_wanted:crime', payload)
end

-- =========================================
-- KILL (baseevents) - stable
-- =========================================
AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
    if killerId ~= PlayerId() then return end

    -- data byvá různá podle verze baseevents; zkusíme z ní dostat victim
    -- některé buildy posílají "victim" jako ped/entity, některé ne.
    local victimSrc = KGW.lastVictimServerId or 0
    local dist = KGW.lastVictimDist or 0.0

    if victimSrc > 0 then
        sendCrime({ type = 'kill', victim = victimSrc, dist = dist })
    end
end)

AddEventHandler('baseevents:onPlayerDied', function(_killerType, _coords)
    if KGW.lastAttackerWasMe and (KGW.lastVictimServerId or 0) > 0 then
        sendCrime({ type = 'kill', victim = KGW.lastVictimServerId, dist = KGW.lastVictimDist or 0.0 })
    end
end)

-- =========================================
-- DAMAGE EVENT (cache victim + runover)
-- =========================================
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1
    local weaponHash = args[7]

    if not victim or not DoesEntityExist(victim) or not IsEntityAPed(victim) then return end

    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    if victimPlayer == -1 then return end

    local victimSrc = GetPlayerServerId(victimPlayer)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local dist = #(GetEntityCoords(myPed) - GetEntityCoords(victim))

    -- cache for kill fallback
    KGW.lastVictimServerId = victimSrc
    KGW.lastVictimDist = dist

    KGW.lastAttackerWasMe = false
    if attacker and attacker ~= 0 and DoesEntityExist(attacker) and IsEntityAPed(attacker) then
        local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)
        if attackerPlayer ~= -1 and attackerPlayer == PlayerId() then
            KGW.lastAttackerWasMe = true
        end
    end

    -- runover via weapon hash
    if weaponHash == WEAPON_RUN_OVER_BY_CAR or weaponHash == WEAPON_RAMMED_BY_CAR then
        local veh = GetVehiclePedIsIn(myPed, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == myPed then
            local now = GetGameTimer()
            if now - (KGW.lastRunoverReport or 0) >= 2000 then
                KGW.lastRunoverReport = now

                sendCrime({
                    type = 'runover',
                    victim = victimSrc,
                    dist = dist,
                    died = victimDied
                })
            end
        end
        return
    end

    -- no hurt wanted (even fists), only kill triggers above
end)
