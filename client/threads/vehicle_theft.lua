-- KG_Wanted/client/threads/vehicle_theft.lua
-- Wanted for stealing NPC vehicle (not from player)

local attempts = {} -- [veh] = { npcDriver = bool, noOtherPlayers = bool, t = gameTimer }
local lastSent = {} -- [plate] = gameTimer

local function normPlate(p)
    if not p then return '' end
    return (p:gsub('%s+', ''))
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

CreateThread(function()
    while true do
        Wait(150)

        local ped = PlayerPedId()

        -- 1) detect "trying to enter" and remember context
        local tryingVeh = GetVehiclePedIsTryingToEnter(ped)
        if tryingVeh and tryingVeh ~= 0 and DoesEntityExist(tryingVeh) then
            if not attempts[tryingVeh] then
                local driver = GetPedInVehicleSeat(tryingVeh, -1)
                local npcDriver = (driver and driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver))
                local otherPlayers = anyOtherPlayerInVehicle(tryingVeh)

                attempts[tryingVeh] = {
                    npcDriver = npcDriver,
                    noOtherPlayers = (otherPlayers == false),
                    t = GetGameTimer()
                }
            end
        end

        -- 2) if you became the driver shortly after -> report NPC theft
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                local a = attempts[veh]
                if a and a.npcDriver and a.noOtherPlayers and (GetGameTimer() - a.t) < 10000 then
                    local plate = normPlate(GetVehicleNumberPlateText(veh))
                    if plate == '' then plate = tostring(NetworkGetNetworkIdFromEntity(veh)) end

                    local now = GetGameTimer()
                    if (lastSent[plate] or 0) + 60000 < now then
                        lastSent[plate] = now
                        TriggerServerEvent('kg_wanted:crime', {
                            type = 'veh_theft_npc',
                            vehNetId = NetworkGetNetworkIdFromEntity(veh),
                            dist = 0.0
                        })
                    end

                    attempts[veh] = nil
                end
            end
        end

        -- cleanup old attempts
        local now = GetGameTimer()
        for veh, a in pairs(attempts) do
            if not DoesEntityExist(veh) or (now - (a.t or 0)) > 15000 then
                attempts[veh] = nil
            end
        end
    end
end)
