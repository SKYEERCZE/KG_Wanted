-- KG_Wanted/client/threads/vehicle_theft.lua
-- Robust NPC vehicle theft detection:
--  - When you become DRIVER of a vehicle
--  - If IsVehicleStolen(vehicle) == true
--  - And no other players are in the vehicle
--  => crime veh_theft_npc (cooldown per vehicle)

local lastVeh = 0
local lastSent = {} -- [key] = gameTimer

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
        Wait(250)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                if veh ~= lastVeh then
                    lastVeh = veh

                    -- ignore if other players are in the car
                    if anyOtherPlayerInVehicle(veh) then goto continue end

                    -- this is the key: GTA flags stolen vehicles
                    if IsVehicleStolen(veh) then
                        local plate = normPlate(GetVehicleNumberPlateText(veh))
                        local key = plate ~= '' and plate or ('net:' .. tostring(NetworkGetNetworkIdFromEntity(veh)))

                        local now = GetGameTimer()
                        if (lastSent[key] or 0) + 60000 < now then
                            lastSent[key] = now

                            TriggerServerEvent('kg_wanted:crime', {
                                type = 'veh_theft_npc',
                                vehNetId = NetworkGetNetworkIdFromEntity(veh),
                                dist = 0.0
                            })
                        end
                    end
                end
            end
        else
            lastVeh = 0
        end

        ::continue::
    end
end)
