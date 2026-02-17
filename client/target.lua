CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(300) end

    -- Police: jail (police-only)
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

    -- Suspect: request clean from lawyer (anywhere) – only shows on LAWYER
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

                    -- ✅ show only on lawyer + lawyer must not be wanted
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

    -- Police duty circle on station
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
