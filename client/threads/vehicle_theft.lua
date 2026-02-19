-- KG_Wanted/client/threads/vehicle_theft.lua
-- Carjack-based theft detection (anim/action based):
--  - Only triggers when player is actually jacking someone out OR breaks window while trying to enter
--  - Prevents stars for "already stolen / empty vehicle"
--  - Filters both NPC and players (action-based)

local COOLDOWN_MS = 60000        -- 60s per vehicle key
local ATTEMPT_TTL_MS = 12000     -- attempt window
local WINDOW_CHECK_MS = 1800     -- time window to detect window breaking
local MIN_SPEED_IGNORE_KMH = 2.0 -- ignore weird states while vehicle moving

local attempts = {} -- [veh] = { t, seat, hadOccupant, occupantIsPlayer, winIntact, winCheckedAt, evidenceJacking, evidenceWindow, key }
local lastSent = {} -- [key] = gameTimer

local function normPlate(p)
    if not p then return '' end
    return (p:gsub('%s+', ''))
end

local function getVehKey(veh)
    local plate = normPlate(GetVehicleNumberPlateText(veh))
    if plate ~= '' then return 'plate:' .. plate end
    return 'net:' .. tostring(NetworkGetNetworkIdFromEntity(veh))
end

local function anyOtherPlayerInVehicle(veh)
    local maxSeats = GetVehicleMaxNumberOfPassengers(veh) or 0
    for seat = -1, maxSeats do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) then
            if NetworkGetPlayerIndexFromPed(ped) ~= PlayerId() then
                return true
            end
        end
    end
    return false
end

local function getTryingSeat(ped, veh)
    -- Někdy lze získat seat přes GetSeatPedIsTryingToEnter (není vždy dostupné),
    -- proto fallback: když je obsazený řidič, předpokládej -1, jinak -1 (driver) je nejčastější.
    -- Pro účely "carjack evidence" to stačí.
    return -1
end

local function driverWindowIndex()
    -- GTA: 0 = front left (driver)
    return 0
end

CreateThread(function()
    while true do
        Wait(120)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        -- 1) Zachyť pokus o nastoupení (před usednutím)
        local tryingVeh = GetVehiclePedIsTryingToEnter(ped)
        if tryingVeh and tryingVeh ~= 0 and DoesEntityExist(tryingVeh) then
            if not attempts[tryingVeh] then
                -- ignoruj, když auto jede (často glitch stavy)
                local speed = GetEntitySpeed(tryingVeh) * 3.6
                if speed > MIN_SPEED_IGNORE_KMH then goto continue end

                local seat = getTryingSeat(ped, tryingVeh)
                local occupant = GetPedInVehicleSeat(tryingVeh, seat)
                local hadOccupant = occupant and occupant ~= 0 and DoesEntityExist(occupant)

                local occupantIsPlayer = hadOccupant and IsPedAPlayer(occupant)
                local winIdx = driverWindowIndex()
                local intact = IsVehicleWindowIntact(tryingVeh, winIdx)

                attempts[tryingVeh] = {
                    t = GetGameTimer(),
                    seat = seat,
                    hadOccupant = hadOccupant,
                    occupantIsPlayer = occupantIsPlayer,
                    winIntact = intact,
                    winCheckedAt = GetGameTimer(),
                    evidenceJacking = false,
                    evidenceWindow = false,
                    key = getVehKey(tryingVeh),
                }
            end

            -- Evidence 1: jacking anim/action
            -- Pokud hráč “vyhazuje” někoho z auta, tohle typicky vrací true
            if IsPedJacking(ped) then
                attempts[tryingVeh].evidenceJacking = true
            end

            -- Evidence 2: window broke during attempt (within WINDOW_CHECK_MS)
            local a = attempts[tryingVeh]
            if a and (GetGameTimer() - (a.winCheckedAt or 0)) < WINDOW_CHECK_MS then
                local winIdx = driverWindowIndex()
                local intactNow = IsVehicleWindowIntact(tryingVeh, winIdx)
                if a.winIntact and not intactNow then
                    a.evidenceWindow = true
                end
            end
        end

        -- 2) Pokud už jsi řidič, vyhodnoť attempt + evidence
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                local a = attempts[veh]
                if a then
                    local now = GetGameTimer()

                    -- attempt vypršel
                    if (now - (a.t or 0)) > ATTEMPT_TTL_MS then
                        attempts[veh] = nil
                        goto continue
                    end

                    -- nechceme hvězdy za “sedl do prázdného” (bez oběti)
                    if not a.hadOccupant then
                        attempts[veh] = nil
                        goto continue
                    end

                    -- Evidence musí být: jacking nebo okno rozbito
                    local evidence = (a.evidenceJacking == true) or (a.evidenceWindow == true)
                    if not evidence then
                        attempts[veh] = nil
                        goto continue
                    end

                    -- pokud v autě sedí jiný hráč, můžeš to buď:
                    -- A) ignorovat (teď) nebo B) povolit (když chceš hvězdy i za vyhození hráče)
                    if anyOtherPlayerInVehicle(veh) then
                        -- nechávám "ignore" aby to nedělalo bordel při týmové jízdě
                        attempts[veh] = nil
                        goto continue
                    end

                    -- cooldown per vehicle
                    local key = a.key or getVehKey(veh)
                    if (lastSent[key] or 0) + COOLDOWN_MS > now then
                        attempts[veh] = nil
                        goto continue
                    end
                    lastSent[key] = now

                    -- Pošli crime event (server už umí veh_theft_npc)
                    TriggerServerEvent('kg_wanted:crime', {
                        type = 'veh_theft_npc',
                        vehNetId = NetworkGetNetworkIdFromEntity(veh),
                        dist = 0.0
                    })

                    attempts[veh] = nil
                end
            end
        end

        -- 3) Cleanup attempts
        local now = GetGameTimer()
        for v, a in pairs(attempts) do
            if not DoesEntityExist(v) or (now - (a.t or 0)) > (ATTEMPT_TTL_MS + 3000) then
                attempts[v] = nil
            end
        end

        ::continue::
    end
end)
