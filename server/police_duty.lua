local function isNearPoliceDuty(src)
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled) then return true end
    local c = Config.PoliceDuty.DutyCoords
    local coords = GetEntityCoords(GetPlayerPed(src))
    local d = #(coords - vector3(c.x, c.y, c.z))
    return d <= (Config.PoliceDuty.Radius or 2.0)
end

local function buildMissingMessage(missingLabels)
    if #missingLabels == 0 then return nil end
    if #missingLabels == 1 then
        return ('Chybí ti %s.'):format(missingLabels[1])
    end
    return ('Chybí ti %s a %s.'):format(missingLabels[1], missingLabels[2])
end

local function hasItem(xPlayer, itemName)
    local item = xPlayer.getInventoryItem(itemName)
    return item and (tonumber(item.count) or 0) > 0
end

local function canGoPoliceDuty(src, cb)
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled) then cb(true, nil); return end
    local req = Config.PoliceDuty.Requirements
    if not (req and req.Enabled) then cb(true, nil); return end

    local xPlayer = KGW.ESX.GetPlayerFromId(src)
    if not xPlayer then cb(false, 'ESX player not found'); return end

    if not isNearPoliceDuty(src) then
        cb(false, 'Musíš být na stanici.')
        return
    end

    local map = req.ItemMap or {}
    local driver = map.driver
    local weapon = map.weapon

    local missing = {}

    if driver and driver.item and not hasItem(xPlayer, driver.item) then
        missing[#missing+1] = driver.label or 'Řidičák'
    end
    if weapon and weapon.item and not hasItem(xPlayer, weapon.item) then
        missing[#missing+1] = weapon.label or 'Zbrojní průkaz'
    end

    if #missing > 0 then
        cb(false, buildMissingMessage(missing) or 'Chybí požadované itemy.')
        return
    end

    cb(true, nil)
end

RegisterNetEvent('kg_wanted:policeDutyToggle', function(makeOnDuty)
    local src = source
    makeOnDuty = makeOnDuty == true

    local xPlayer = KGW.ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled) then return end

    if makeOnDuty then
        canGoPoliceDuty(src, function(ok, err)
            if not ok then
                TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = err or 'Nesplňuješ podmínky.' })
                return
            end

            xPlayer.setJob(Config.PoliceJob, tonumber(Config.PoliceDuty.PoliceGrade) or 0)
            Player(src).state.kg_police_duty = true
            TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Nastoupil jsi službu LSPD.' })

            -- refresh job flags
            KGW.setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
        end)
    else
        xPlayer.setJob(Config.UnemployedJob, 0)
        Player(src).state.kg_police_duty = false
        TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Ukončil jsi službu.' })

        KGW.setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
    end
end)

CreateThread(function()
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled and Config.PoliceDuty.EnforceStationOnly) then return end
    while true do
        Wait((tonumber(Config.PoliceDuty.EnforceCheckSeconds) or 10) * 1000)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local xPlayer = KGW.ESX.GetPlayerFromId(src)
            if xPlayer and KGW.isPolice(xPlayer) then
                local onDuty = Player(src).state.kg_police_duty == true
                if not onDuty then
                    xPlayer.setJob(Config.UnemployedJob, 0)
                    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Police job lze pouze přes nástup na stanici.' })
                    KGW.setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
                end
            end
        end
    end
end)
