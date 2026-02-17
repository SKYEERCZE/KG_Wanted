KGW = KGW or {}

-- seznam právníků (server posílá jen wanted hráčům)
KGW.Client = KGW.Client or {}
KGW.Client.LawyerSet = {}

RegisterNetEvent(KGW.Const.Events.SyncLawyers, function(list)
    KGW.Client.LawyerSet = {}
    if type(list) ~= 'table' then return end
    for _, sid in ipairs(list) do
        KGW.Client.LawyerSet[tonumber(sid)] = true
    end
end)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(300) end

    -- Police: jail
    exports.ox_target:addGlobalPlayer({
        {
            name = 'kg_wanted_jail',
            icon = 'fa-solid fa-handcuffs',
            label = 'Poslat do basy',
            distance = Config.Interaction.Distance or 2.2,
            canInteract = function(entity, distance)
                if not (KGW.Client and KGW.Client.isPoliceCached) then return false end
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
                    label = 'Zatykani...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                })
                if not ok then return end

                TriggerServerEvent(KGW.Const.Events.PoliceJail, targetSrc)
            end
        }
    })

    -- Suspect: request clean from lawyer (jen pokud je target pravnik)
    if Config.Lawyer and Config.Lawyer.Enabled then
        exports.ox_target:addGlobalPlayer({
            {
                name = 'kg_wanted_ask_lawyer',
                icon = Config.Lawyer.RequestIcon or 'fa-solid fa-scale-balanced',
                label = Config.Lawyer.RequestLabel or 'Pozadat o ocistu',
                distance = Config.Lawyer.Distance or 2.2,
                canInteract = function(entity, distance)
                    if distance > (Config.Lawyer.Distance or 2.2) then return false end
                    if not DoesEntityExist(entity) or not IsEntityAPed(entity) then return false end

                    local myStars = LocalPlayer.state.kg_wanted or 0
                    if (tonumber(myStars) or 0) <= 0 then return false end

                    local ply = NetworkGetPlayerIndexFromPed(entity)
                    if ply == -1 then return false end
                    local targetSrc = GetPlayerServerId(ply)
                    if targetSrc <= 0 then return false end

                    -- ✅ pouze na pravniky (server sync)
                    return KGW.Client.LawyerSet[targetSrc] == true
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
                        label = 'Ocista...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                    })
                    if not ok then return end

                    TriggerServerEvent(KGW.Const.Events.LawyerRequestClean, lawyerSrc)
                end
            }
        })
    end

    -- Police duty sphere zone
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
                    label = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.LabelOn) or 'Nastoupit sluzbu LSPD',
                    onSelect = function()
                        TriggerServerEvent(KGW.Const.Events.PoliceDutyToggle, true)
                    end
                },
                {
                    name = 'kg_police_duty_off',
                    icon = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.IconOff) or 'fa-solid fa-badge',
                    label = (Config.PoliceDuty.Target and Config.PoliceDuty.Target.LabelOff) or 'Ukoncit sluzbu LSPD',
                    onSelect = function()
                        TriggerServerEvent(KGW.Const.Events.PoliceDutyToggle, false)
                    end
                }
            }
        })
    end
end)
