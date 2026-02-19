-- client/threads/vehicle_theft.lua
-- Wanted za krádež NPC vozidla (best-effort)

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
        Wait(200)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                if anyOtherPlayerInVehicle(veh) then goto continue end

                local plate = normPlate(GetVehicleNumberPlateText(veh))
                if plate == '' then plate = tostring(NetworkGetNetworkIdFromEntity(veh)) end

                local now = GetGameTimer()
                if (lastSent[plate] or 0) + 60000 > now then goto continue end
                lastSent[plate] = now

                TriggerServerEvent('kg_wanted:crime', {
                    type = 'veh_theft_npc',
                    vehNetId = NetworkGetNetworkIdFromEntity(veh),
                    dist = 0.0
                })
            end
        end

        ::continue::
    end
end)
