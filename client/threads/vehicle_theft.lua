-- KG_Wanted/client/threads/vehicle_theft.lua
-- Krádež vozidla od NPC (ne od hráče)

local attempts = {} -- [veh] = { npcDriver = bool, noOtherPlayers = bool, t = gameTimer }

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

        -- 1) Když se snažíš nastoupit do vozidla, označíme si ho
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

        -- 2) Pokud už řídíš, a bylo to “NPC auto”, nahlásíme krádež
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and DoesEntityExist(veh) then
                if GetPedInVehicleSeat(veh, -1) == ped then
                    local a = attempts[veh]
                    if a and a.npcDriver and a.noOtherPlayers and (GetGameTimer() - a.t) < 10000 then
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        TriggerServerEvent('kg_wanted:crime', {
                            type = 'veh_theft_npc',
                            vehNetId = netId,
                            dist = 0.0
                        })
                        attempts[veh] = nil
                    end
                end
            end
        end

        -- cleanup starých pokusů
        local now = GetGameTimer()
        for veh, a in pairs(attempts) do
            if not DoesEntityExist(veh) or (now - (a.t or 0)) > 15000 then
                attempts[veh] = nil
            end
        end
    end
end)
