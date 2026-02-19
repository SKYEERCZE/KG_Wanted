-- KG_Wanted/client/threads/crime_detection.lua
-- Robust wanted detection:
--  - KILL: tag damage -> confirm death in separate loop (fixes "victimDied not in same event")
--  - RUNOVER: weapon hash + driver check
--  - NO hurt stars (only kill)

KGW = KGW or {}

local WEAPON_RUN_OVER_BY_CAR = GetHashKey('WEAPON_RUN_OVER_BY_CAR')

local lastRunoverReport = 0

-- lastHit[victimSrc] = { pid = clientPlayerId, t = gameTimer, dist = number }
local lastHit = {}
local killReported = {} -- [victimSrc] = gameTimer

local function isMyPed(ent)
    return ent ~= nil and ent ~= 0 and ent == PlayerPedId()
end

local function isMyVehicle(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not IsEntityAVehicle(ent) then return false end
    local driver = GetPedInVehicleSeat(ent, -1)
    return driver ~= 0 and DoesEntityExist(driver) and isMyPed(driver)
end

local function sendKill(victimSrc, dist)
    TriggerServerEvent('kg_wanted:crime', {
        type = 'kill',
        victim = victimSrc,
        dist = dist
    })
end

local function sendRunover(victimSrc, dist, died)
    TriggerServerEvent('kg_wanted:crime', {
        type = 'runover',
        victim = victimSrc,
        dist = dist,
        died = died == true
    })
end

-- DAMAGE TAGGING
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1
    local weaponHash = args[7]

    if not victim or victim == 0 or not DoesEntityExist(victim) or not IsEntityAPed(victim) then return end

    local victimPid = NetworkGetPlayerIndexFromPed(victim)
    if victimPid == -1 then return end

    local victimSrc = GetPlayerServerId(victimPid)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local dist = #(GetEntityCoords(myPed) - GetEntityCoords(victim))

    -- =========================
    -- RUNOVER (stabilní, už ti jde)
    -- =========================
    if weaponHash == WEAPON_RUN_OVER_BY_CAR then
        local veh = GetVehiclePedIsIn(myPed, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == myPed then
        
            -- ✅ filtr: počítat jen sražení od 50+ km/h
            local speedKmh = GetEntitySpeed(veh) * 3.6
            if speedKmh < 50.0 then
                return
            end
        
            local now = GetGameTimer()
            if now - lastRunoverReport >= 1800 then
                lastRunoverReport = now
                sendRunover(victimSrc, dist, victimDied)
            end
        end
        return
    end

    -- =========================
    -- KILL: netvrdíme "victimDied v tom samým eventu"
    -- Tagujeme poslední damage, a kill ověříme ve vlastním loopu.
    -- =========================
    local iDidDamage = false

    -- attacker může být ped/vehicle/0 – ošetříme vše
    if attacker and attacker ~= 0 and DoesEntityExist(attacker) then
        if isMyPed(attacker) or isMyVehicle(attacker) then
            iDidDamage = true
        end
    end

    -- fallback: source of death někdy sedí líp
    if not iDidDamage then
        local src = GetPedSourceOfDeath(victim)
        if isMyPed(src) or isMyVehicle(src) then
            iDidDamage = true
        end
    end

    if iDidDamage then
        lastHit[victimSrc] = { pid = victimPid, t = GetGameTimer(), dist = dist }
    end
end)

-- KILL CONFIRM LOOP
CreateThread(function()
    while true do
        Wait(250)

        local now = GetGameTimer()
        for victimSrc, data in pairs(lastHit) do
            -- timeout po 6s – když neumřel rychle, zahodíme (aby se nefarmilo)
            if not data or (now - (data.t or 0)) > 6000 then
                lastHit[victimSrc] = nil
            else
                local pid = data.pid
                if pid ~= nil and pid ~= -1 then
                    local ped = GetPlayerPed(pid)
                    if ped ~= 0 and DoesEntityExist(ped) and IsEntityDead(ped) then
                        -- anti-spam pro jednu oběť
                        if (killReported[victimSrc] or 0) + 4000 < now then
                            killReported[victimSrc] = now
                            sendKill(victimSrc, data.dist or 0.0)
                        end
                        lastHit[victimSrc] = nil
                    end
                end
            end
        end
    end
end)
