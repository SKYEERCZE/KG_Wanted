-- client/threads/vehicle_theft.lua
-- Wanted for stealing NPC vehicle (NOT from another player)

local lastSent = {} -- [plate] = GetGameTimer()

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

        -- only when you are the driver
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                -- must have been recently "trying to enter" (so we detect theft moment)
                local tryingVeh = GetVehiclePedIsTryingToEnter(ped)
                if tryingVeh == veh then
                    local driverBefore = GetPedInVehicleSeat(veh, -1)

                    -- if any other player is/was in the car -> ignore (player vehicle)
                    if anyOtherPlayerInVehicle(veh) then
                        goto continue
                    end

                    -- if car is owned by NPC / not a player vehicle:
                    -- simplest rule: it must NOT have been occupied by another player and plate event cooldown
                    local plate = normPlate(GetVehicleNumberPlateText(veh))
                    if plate == '' then plate = tostring(NetworkGetNetworkIdFromEntity(veh)) end

                    local now = GetGameTimer()
                    if (lastSent[plate] or 0) + 60000 > now then
                        goto continue
                    end
                    lastSent[plate] = now

                    TriggerServerEvent('kg_wanted:crime', {
                        type = 'veh_theft_npc',
                        vehNetId = NetworkGetNetworkIdFromEntity(veh),
                        dist = 0.0
                    })
                end
            end
        end

        ::continue::
    end
end)
