KGW = KGW or {}

local ESX = KGW.Wanted._ESX

local function pickRandomCell()
    local cells = (Config.Jail and Config.Jail.Cells) or nil
    if type(cells) == 'table' and #cells > 0 then
        local idx = math.random(1, #cells)
        local c = cells[idx]
        return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = c.w + 0.0, index = idx }
    end
    local jc = (Config.Jail and Config.Jail.JailCoords) or vector4(0,0,0,0)
    return { x = jc.x + 0.0, y = jc.y + 0.0, z = jc.z + 0.0, w = jc.w + 0.0, index = 0 }
end

-- Police sends suspect to jail immediately
RegisterNetEvent(KGW.Const.Events.PoliceJail, function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)

    local xPolice = ESX.GetPlayerFromId(src)
    if not KGW.Wanted.isPolice(xPolice) then return end
    if not targetSrc or not GetPlayerName(targetSrc) then return end

    local stars = select(1, KGW.Wanted.getStars(targetSrc))
    stars = tonumber(stars) or 0
    if stars < (Config.Interaction.MinStarsToJail or 1) then return end

    local minutes = math.max(Config.Jail.MinMinutes or 2, (Config.Jail.MinutesPerStar or 2) * stars)

    KGW.Rewards.rewardPolice(src, stars)

    local officerName = GetPlayerName(src) or 'Policista'
    local cell = pickRandomCell()

    KGW.Wanted.clearWanted(targetSrc)
    TriggerClientEvent(KGW.Const.Events.GoJail, targetSrc, minutes, { officer = officerName, cell = cell })
end)

-- ===== Police duty requirements (items) =====
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
        return ('Chybi ti %s.'):format(missingLabels[1])
    end
    return ('Chybi ti %s a %s.'):format(missingLabels[1], missingLabels[2])
end

local function hasItem(xPlayer, itemName)
    local item = xPlayer.getInventoryItem(itemName)
    return item and (tonumber(item.count) or 0) > 0
end

local function canGoPoliceDuty(src, cb)
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled) then cb(true, nil); return end
    local req = Config.PoliceDuty.Requirements
    if not (req and req.Enabled) then cb(true, nil); return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then cb(false, 'ESX player not found'); return end

    if not isNearPoliceDuty(src) then
        cb(false, 'Musis byt na stanici.')
        return
    end

    local map = req.ItemMap or {}
    local driver = map.driver
    local weapon = map.weapon

    local missing = {}

    if driver and driver.item and not hasItem(xPlayer, driver.item) then
        missing[#missing+1] = driver.label or 'Ridicak'
    end
    if weapon and weapon.item and not hasItem(xPlayer, weapon.item) then
        missing[#missing+1] = weapon.label or 'Zbrojni prukaz'
    end

    if #missing > 0 then
        cb(false, buildMissingMessage(missing) or 'Chybi pozadovane itemy.')
        return
    end

    cb(true, nil)
end

RegisterNetEvent(KGW.Const.Events.PoliceDutyToggle, function(makeOnDuty)
    local src = source
    makeOnDuty = makeOnDuty == true

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled) then return end

    if makeOnDuty then
        canGoPoliceDuty(src, function(ok, err)
            if not ok then
                TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = err or 'Nesplnujes podminky.' })
                return
            end

            xPlayer.setJob(Config.PoliceJob, tonumber(Config.PoliceDuty.PoliceGrade) or 0)
            Player(src).state.kg_police_duty = true
            TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Nastoupil jsi sluzbu LSPD.' })
        end)
    else
        xPlayer.setJob(Config.UnemployedJob, 0)
        Player(src).state.kg_police_duty = false
        TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Ukoncil jsi sluzbu.' })
    end
end)

-- Enforce: police job jen přes stanici
CreateThread(function()
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled and Config.PoliceDuty.EnforceStationOnly) then return end
    while true do
        Wait((tonumber(Config.PoliceDuty.EnforceCheckSeconds) or 10) * 1000)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and KGW.Wanted.isPolice(xPlayer) then
                local onDuty = Player(src).state.kg_police_duty == true
                if not onDuty then
                    xPlayer.setJob(Config.UnemployedJob, 0)
                    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Police job lze pouze pres nastup na stanici.' })
                end
            end
        end
    end
end)
