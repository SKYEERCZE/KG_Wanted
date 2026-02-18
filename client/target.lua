CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(300) end

    local function getPlayerFromPed(ped)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
        local ply = NetworkGetPlayerIndexFromPed(ped)
        if ply == -1 then return nil end
        local src = GetPlayerServerId(ply)
        if not src or src <= 0 then return nil end
        return src
    end

    local function findFirstPlayerInVehicle(vehicle, predicateFn)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

        -- projdeme běžná sedadla: -1 = řidič, 0+ = pasažéři
        for seat = -1, 6 do
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped and ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) then
                local src = getPlayerFromPed(ped)
                if src and (not predicateFn or predicateFn(src)) then
                    return src
                end
            end
        end

        return nil
    end

    -- =========================
    -- POLICE: JAIL (PLAYER)
    -- =========================
    exports.ox_target:addGlobalPlayer({
        {
            name = 'kg_wanted_jail',
            icon = 'fa-solid fa-handcuffs',
            label = 'Poslat do basy',
            distance = Config.Interaction.Distance or 2.2,
            canInteract = function(entity, distance)
                if not KGW.cache.isPolice then return false end
                if distance > (Config.Interaction.Distance or 2.2) then return false end
                if not DoesEntityExist(entity) or not IsEntityAPed(entity) then return false end

                local ply = NetworkGetPlayerIndexFromPed(entity)
                if ply == -1 then return false end
                local src = GetPlayerServerId(ply)
                if src <= 0 then return false end

                local stars = Player(src).state.kg_wanted or 0
                return stars >= (Config.Interaction.MinStarsToJail or 1)
            end,
            onSelect = function(data)
                local entity = data.entity
                if not DoesEntityExist(entity) then return end

                local ply = NetworkGetPlayerIndexFromPed(entity)
                if ply == -1 then return end
                local targetSrc = GetPlayerServerId(ply)
                if targetSrc <= 0 then return end

                local ok = lib.progressBar({
                    duration = Config.Interaction.ActionTimeMs or 3500,
                    label = 'Zatýkání...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                })
                if not ok then return end

                TriggerServerEvent('kg_wanted:policeJail', targetSrc)
            end
        }
    })

    -- =========================
    -- POLICE: JAIL (VEHICLE) ✅ nově
    -- =========================
    exports.ox_target:addGlobalVehicle({
        {
            name = 'kg_wanted_jail_vehicle',
            icon = 'fa-solid fa-handcuffs',
            label = 'Poslat do basy (z vozidla)',
            distance = Config.Interaction.Distance or 2.2,
            canInteract = function(vehicle, distance)
                if not KGW.cache.isPolice then return false end
                if distance > (Config.Interaction.Distance or 2.2) then return false end
                if not DoesEntityExist(vehicle) then return false end

                -- najdi prvního hráče ve vozidle, co má wanted
                local targetSrc = findFirstPlayerInVehicle(vehicle, function(src)
                    local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
                    return stars >= (Config.Interaction.MinStarsToJail or 1)
                end)

                return targetSrc ~= nil
            end,
            onSelect = function(data)
                local vehicle = data.entity
                if not DoesEntityExist(vehicle) then return end

                local targetSrc = findFirstPlayerInVehicle(vehicle, function(src)
                    local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
                    return stars >= (Config.Interaction.MinStarsToJail or 1)
                end)
                if not targetSrc then return end

                local ok = lib.progressBar({
                    duration = Config.Interaction.ActionTimeMs or 3500,
                    label = 'Zatýkání...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                })
                if not ok then return end

                TriggerServerEvent('kg_wanted:policeJail', targetSrc)
            end
        }
    })

    -- =========================
    -- LAWYER: REQUEST CLEAN (PLAYER)
    -- =========================
    if Config.Lawyer and Config.Lawyer.Enabled then
        exports.ox_target:addGlobalPlayer({
            {
                name = 'kg_wanted_ask_lawyer',
                icon = Config.Lawyer.RequestIcon or 'fa-solid fa-scale-balanced',
                label = Config.Lawyer.RequestLabel or 'Požádat o očistu',
                distance = Config.Lawyer.Distance or 2.2,
                canInteract = function(entity, distance)
                    if distance > (Config.Lawyer.Distance or 2.2) then return false end
                    if not DoesEntityExist(entity) or not IsEntityAPed(entity) then return false end

                    local myStars = tonumber(LocalPlayer.state.kg_wanted or 0) or 0
                    if myStars <= 0 then return false end

                    local ply = NetworkGetPlayerIndexFromPed(entity)
                    if ply == -1 then return false end
                    local targetSrc = GetPlayerServerId(ply)
                    if targetSrc <= 0 then return false end

                    local isLawyer = Player(targetSrc).state.kg_isLawyer == true
                    if not isLawyer then return false end

                    local lawyerStars = tonumber(Player(targetSrc).state.kg_wanted or 0) or 0
                    if lawyerStars > 0 then return false end

                    return true
                end,
                onSelect = function(data)
                    local entity = data.entity
                    if not DoesEntityExist(entity) then return end

                    local ply = NetworkGetPlayerIndexFromPed(entity)
                    if ply == -1 then return end
                    local lawyerSrc = GetPlayerServerId(ply)
                    if lawyerSrc <= 0 then return end

                    local ok = lib.progressBar({
                        duration = Config.Lawyer.ActionTimeMs or 5500,
                        label = 'Očista...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                    })
                    if not ok then return end

                    TriggerServerEvent('kg_wanted:lawyerRequestClean', lawyerSrc)
                end
            }
        })
    end

    -- =========================
    -- LAWYER: REQUEST CLEAN (VEHICLE) ✅ nově
    -- =========================
    if Config.Lawyer and Config.Lawyer.Enabled then
        exports.ox_target:addGlobalVehicle({
            {
                name = 'kg_wanted_ask_lawyer_vehicle',
                icon = Config.Lawyer.RequestIcon or 'fa-solid fa-scale-balanced',
                label = (Config.Lawyer.RequestLabel or 'Požádat o očistu') .. ' (u vozidla)',
                distance = Config.Lawyer.Distance or 2.2,
                canInteract = function(vehicle, distance)
                    if distance > (Config.Lawyer.Distance or 2.2) then return false end
                    if not DoesEntityExist(vehicle) then return false end

                    local myStars = tonumber(LocalPlayer.state.kg_wanted or 0) or 0
                    if myStars <= 0 then return false end

                    local lawyerSrc = findFirstPlayerInVehicle(vehicle, function(src)
                        local isLawyer = Player(src).state.kg_isLawyer == true
                        if not isLawyer then return false end
                        local lawyerStars = tonumber(Player(src).state.kg_wanted or 0) or 0
                        return lawyerStars <= 0
                    end)

                    return lawyerSrc ~= nil
                end,
                onSelect = function(data)
                    local vehicle = data.entity
                    if not DoesEntityExist(vehicle) then return end

                    local lawyerSrc = findFirstPlayerInVehicle(vehicle, function(src)
                        local isLawyer = Player(src).state.kg_isLawyer == true
                        if not isLawyer then return false end
                        local lawyerStars = tonumber(Player(src).state.kg_wanted or 0) or 0
                        return lawyerStars <= 0
                    end)
                    if not lawyerSrc then return end

                    local ok = lib.progressBar({
                        duration = Config.Lawyer.ActionTimeMs or 5500,
                        label = 'Očista...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                    })
                    if not ok then return end

                    TriggerServerEvent('kg_wanted:lawyerRequestClean', lawyerSrc)
                end
            }
        })
    end

    -- =========================
    -- POLICE DUTY ZONE
    -- =========================
    if Config.PoliceDuty and Config.PoliceDuty.Enabled then
        local c = Config.PoliceDuty.DutyCoords
        exports.ox_target:addSphereZone({
            coords = vec3(c.x, c.y, c.z),
            radius = Config.PoliceDuty.Radius or 2.0,
            debug = false,
            options = {
                {
                    name = 'kg_police_duty_on',
                    icon = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.IconOn) or 'fa-solid fa-badge',
                    label = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.LabelOn) or 'Nastoupit službu LSPD',
                    onSelect = function()
                        TriggerServerEvent('kg_wanted:policeDutyToggle', true)
                    end
                },
                {
                    name = 'kg_police_duty_off',
                    icon = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.IconOff) or 'fa-solid fa-badge',
                    label = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.LabelOff) or 'Ukončit službu LSPD',
                    onSelect = function()
                        TriggerServerEvent('kg_wanted:policeDutyToggle', false)
                    end
                }
            }
        })
    end
end)
