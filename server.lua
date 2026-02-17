local ESX = exports['es_extended']:getSharedObject()

local Wanted = {}
local HurtCooldown = {}

local function dbg(...)
    if Config.Debug then
        print('[KG_Wanted]', ...)
    end
end

-- ===== DB Abstraction (oxmysql / mysql-async) =====
local function db_driver()
    local d = (Config.Persistence and Config.Persistence.Driver) or 'auto'
    if d ~= 'auto' then return d end
    if GetResourceState('oxmysql') == 'started' then return 'oxmysql' end
    if GetResourceState('mysql-async') == 'started' then return 'mysql-async' end
    return 'none'
end

local function db_exec(query, params)
    local driver = db_driver()
    params = params or {}

    if driver == 'oxmysql' then
        return exports.oxmysql:execute(query, params)
    elseif driver == 'mysql-async' then
        MySQL.Async.execute(query, params)
        return true
    else
        dbg('DB disabled / driver not found. Query skipped:', query)
        return false
    end
end

local function db_fetchAll(query, params, cb)
    local driver = db_driver()
    params = params or {}

    if driver == 'oxmysql' then
        local res = exports.oxmysql:query_async(query, params)
        cb(res or {})
    elseif driver == 'mysql-async' then
        MySQL.Async.fetchAll(query, params, function(res)
            cb(res or {})
        end)
    else
        cb({})
    end
end

-- ===== Helpers =====
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function isPolice(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.name == Config.PoliceJob
end

local function isLawyer(xPlayer)
    return Config.Lawyer and Config.Lawyer.Enabled and xPlayer and xPlayer.job and xPlayer.job.name == (Config.Lawyer.JobName or 'lawyer')
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function ensureEntry(src)
    if not Wanted[src] then
        Wanted[src] = {
            identifier = getIdentifier(src) or '',
            stars = 0,
            lastReason = '',
            lastPos = vec3(0.0, 0.0, 0.0),
            lastUpdate = os.time(),
        }
    end
    if Wanted[src].identifier == '' then
        Wanted[src].identifier = getIdentifier(src) or ''
    end
    return Wanted[src]
end

-- ===== Wanted persistence =====
local function persistWanted(identifier, stars, reason)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not identifier or identifier == '' then return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    stars = tonumber(stars) or 0
    reason = tostring(reason or '')

    if stars <= 0 then
        db_exec(('DELETE FROM %s WHERE identifier = ?'):format(tableName), { identifier })
        return
    end

    db_exec(
        ('INSERT INTO %s (identifier, stars, reason) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stars = VALUES(stars), reason = VALUES(reason), updated_at = CURRENT_TIMESTAMP'):format(tableName),
        { identifier, stars, reason }
    )
end

local function loadWanted(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0, '') return end
    if not identifier or identifier == '' then cb(0, '') return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    db_fetchAll(('SELECT stars, reason FROM %s WHERE identifier = ? LIMIT 1'):format(tableName), { identifier }, function(rows)
        if rows and rows[1] then
            cb(tonumber(rows[1].stars) or 0, tostring(rows[1].reason or ''))
        else
            cb(0, '')
        end
    end)
end

local function setStatebags(src, stars, reason)
    Player(src).state.kg_wanted = stars
    Player(src).state.kg_wanted_reason = reason or ''

    -- ✅ job flags for client (ox_target filters + marker)
    local xPlayer = ESX.GetPlayerFromId(src)
    local jobName = xPlayer and xPlayer.job and xPlayer.job.name or ''
    Player(src).state.kg_isPolice = (jobName == Config.PoliceJob)
    Player(src).state.kg_isLawyer = (Config.Lawyer and Config.Lawyer.Enabled and jobName == (Config.Lawyer.JobName or 'lawyer'))
end

local function setStars(src, stars, reason)
    local entry = ensureEntry(src)
    local oldStars = entry.stars or 0

    entry.stars = clamp(tonumber(stars) or 0, 0, Config.MaxStars)
    entry.lastReason = reason or entry.lastReason or ''
    entry.lastUpdate = os.time()

    setStatebags(src, entry.stars, entry.lastReason)
    persistWanted(entry.identifier, entry.stars, entry.lastReason)

    if Config.NotifyOnStarsGain and entry.stars > oldStars then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            title = '🚨 WANTED',
            description = ('Získal jsi %d★ - %s'):format(entry.stars, (entry.lastReason ~= '' and entry.lastReason or 'Přestupek'))
        })
    end
end

local function addStars(src, add, reason)
    local entry = ensureEntry(src)
    setStars(src, (entry.stars or 0) + (tonumber(add) or 0), reason)
end

local function clearWanted(src)
    setStars(src, 0, '')
end

local function getStars(src)
    local entry = ensureEntry(src)
    return entry.stars or 0, entry.lastReason or ''
end

-- ===== Lawyer cooldown persistence =====
local function lawyerTable()
    return (Config.Lawyer and Config.Lawyer.CooldownTable) or 'kg_wanted_lawyer'
end

local function persistLawyerCooldown(identifier, unixTs)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not identifier or identifier == '' then return end

    unixTs = tonumber(unixTs) or 0
    local t = lawyerTable()

    db_exec(
        ('INSERT INTO %s (identifier, last_help_unix) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_help_unix = VALUES(last_help_unix), updated_at = CURRENT_TIMESTAMP'):format(t),
        { identifier, unixTs }
    )
end

local function loadLawyerCooldown(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0) return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then cb(0) return end
    if not identifier or identifier == '' then cb(0) return end

    local t = lawyerTable()
    db_fetchAll(('SELECT last_help_unix FROM %s WHERE identifier = ? LIMIT 1'):format(t), { identifier }, function(rows)
        if rows and rows[1] then cb(tonumber(rows[1].last_help_unix) or 0) else cb(0) end
    end)
end

-- ===== Happy hour =====
local function isHappyHourNow()
    if not (Config.HappyHour and Config.HappyHour.Enabled) then return false end

    local startH = tonumber(Config.HappyHour.StartHour) or 18
    local endH = tonumber(Config.HappyHour.EndHour) or 22
    local h = tonumber(os.date('%H')) or 0

    if startH == endH then return true end
    if startH < endH then
        return h >= startH and h < endH
    else
        return (h >= startH) or (h < endH)
    end
end

local function rewardLawyer(lawyerSrc, stars)
    local xLawyer = ESX.GetPlayerFromId(lawyerSrc)
    if not isLawyer(xLawyer) then return 0, 1.0 end

    local perStar = tonumber(Config.Lawyer.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = 1.0
    if isHappyHourNow() then mult = tonumber(Config.HappyHour.Multiplier) or 2.0 end

    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Lawyer.Account or 'bank')
    if account == 'bank' then xLawyer.addAccountMoney('bank', amount)
    elseif account == 'money' then xLawyer.addMoney(amount)
    else xLawyer.addAccountMoney('bank', amount) end

    return amount, mult
end

local function rewardPolice(policeSrc, stars)
    if not (Config.Rewards and Config.Rewards.Enabled) then return 0, 1.0 end
    local xPolice = ESX.GetPlayerFromId(policeSrc)
    if not isPolice(xPolice) then return 0, 1.0 end

    local perStar = tonumber(Config.Rewards.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = 1.0
    if isHappyHourNow() then mult = tonumber(Config.HappyHour.Multiplier) or 2.0 end

    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Rewards.Account or 'bank')
    if account == 'bank' then xPolice.addAccountMoney('bank', amount)
    elseif account == 'money' then xPolice.addMoney(amount)
    else xPolice.addAccountMoney('bank', amount) end

    TriggerClientEvent('kg_wanted:rewardBig', policeSrc, amount, mult)
    return amount, mult
end

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

-- ===== Police duty requirements (ITEMS with detailed missing info) =====
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

    local xPlayer = ESX.GetPlayerFromId(src)
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

-- ===== Zones broadcast =====
local function broadcastZones()
    local payload = {}
    for src, entry in pairs(Wanted) do
        if entry.stars and entry.stars >= (Config.Visibility.ZoneMinStars or 2) then
            payload[#payload+1] = {
                src = src,
                stars = entry.stars,
                pos = entry.lastPos,
                reason = entry.lastReason or '',
            }
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local xPlayer = ESX.GetPlayerFromId(id)
        if isPolice(xPlayer) then
            TriggerClientEvent('kg_wanted:policeZones', id, payload)
        end
    end
end

CreateThread(function()
    while true do
        Wait((Config.Visibility.ZoneUpdateSeconds or 8) * 1000)
        broadcastZones()
    end
end)

-- ===== Events =====
RegisterNetEvent('kg_wanted:updatePos', function(pos)
    local src = source
    if type(pos) ~= 'table' or pos.x == nil or pos.y == nil or pos.z == nil then return end
    local entry = ensureEntry(src)
    entry.lastPos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
end)

RegisterNetEvent('kg_wanted:crime', function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local victim = tonumber(data.victim or -1)
    local crimeType = tostring(data.type or '')
    local dist = tonumber(data.dist or 9999.0)

    if victim <= 0 or not GetPlayerName(victim) then return end
    if attacker == victim then return end
    if dist > 200.0 then return end

    local xAttacker = ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = isPolice(xAttacker)
    local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

    local add = 0
    local reason = ''

    if crimeType == 'kill' then
        add = Config.Stars.KillPlayer or 2
        reason = 'Vražda hráče'
    elseif crimeType == 'hurt' then
        local now = os.time()
        local cd = HurtCooldown[attacker] or 0
        if now - cd < (Config.HurtCooldownSeconds or 20) then return end
        HurtCooldown[attacker] = now

        add = Config.Stars.HurtPlayer or 1
        reason = 'Napadení hráče'
    end

    if add <= 0 then return end

    -- 🔴 POLICE CODEX LOGIKA
    if isCop and victimStars <= 0 then
        add = add + (Config.Stars.PoliceExtraStars or 1)

        -- shodit z práce
        xAttacker.setJob(Config.UnemployedJob, 0)
        Player(attacker).state.kg_police_duty = false

        -- červená GTA hláška
        TriggerClientEvent('kg_wanted:codexTop', attacker, {
            title = 'KODEX PORUSEN',
            desc = 'Porušil jsi kodex policie.'
        })
    end

    addStars(attacker, add, reason)
end)

RegisterNetEvent('kg_wanted:policeJail', function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)

    local xPolice = ESX.GetPlayerFromId(src)
    if not isPolice(xPolice) then return end
    if not targetSrc or not GetPlayerName(targetSrc) then return end

    local stars = getStars(targetSrc)
    stars = tonumber(stars) or 0
    if stars < (Config.Interaction.MinStarsToJail or 1) then return end

    local minutes = math.max(Config.Jail.MinMinutes or 2, (Config.Jail.MinutesPerStar or 2) * stars)

    rewardPolice(src, stars)

    local officerName = GetPlayerName(src) or 'Policista'
    local cell = pickRandomCell()

    clearWanted(targetSrc)
    TriggerClientEvent('kg_wanted:goJail', targetSrc, minutes, { officer = officerName, cell = cell })
end)

RegisterNetEvent('kg_wanted:lawyerRequestClean', function(lawyerSrc)
    local suspectSrc = source
    lawyerSrc = tonumber(lawyerSrc)

    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not lawyerSrc or not GetPlayerName(lawyerSrc) then return end
    if suspectSrc == lawyerSrc then return end

    local xLawyer = ESX.GetPlayerFromId(lawyerSrc)
    if not isLawyer(xLawyer) then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Tenhle hráč není právník.' })
        return
    end

    local lawyerStars = tonumber(Player(lawyerSrc).state.kg_wanted or 0) or 0
    if lawyerStars > 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Právník má wanted – nemůže tě očistit.' })
        TriggerClientEvent('ox_lib:notify', lawyerSrc, { type = 'error', description = 'Máš wanted – nemůžeš poskytovat právní služby.' })
        return
    end

    local suspectStars = tonumber(Player(suspectSrc).state.kg_wanted or 0) or 0
    if suspectStars <= 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Nemáš wanted.' })
        return
    end

    local suspectEntry = ensureEntry(suspectSrc)
    local identifier = suspectEntry.identifier or getIdentifier(suspectSrc) or ''
    if identifier == '' then return end

    local cdMin = tonumber(Config.Lawyer.CooldownMinutes) or 30
    local cdSec = cdMin * 60
    local now = os.time()

    local done = false
    local remaining = 0
    loadLawyerCooldown(identifier, function(last)
        last = tonumber(last) or 0
        local diff = now - last
        if diff < cdSec then remaining = cdSec - diff else remaining = 0 end
        done = true
    end)
    while not done do Wait(0) end

    if remaining > 0 then
        TriggerClientEvent('kg_wanted:lawyerDenied', suspectSrc, remaining)
        return
    end

    local sp = GetEntityCoords(GetPlayerPed(suspectSrc))
    local lp = GetEntityCoords(GetPlayerPed(lawyerSrc))
    local dist = #(sp - lp)
    if dist > (Config.Lawyer.Distance or 2.2) + 0.5 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Musíš být blíž u právníka.' })
        return
    end

    local newStars = 0
    local removed = 0
    local mode = Config.Lawyer.Mode or 'clear'
    if mode == 'reduce' then
        local reduceBy = tonumber(Config.Lawyer.ReduceBy) or 1
        newStars = math.max(0, suspectStars - reduceBy)
        removed = suspectStars - newStars
    else
        newStars = 0
        removed = suspectStars
    end

    local pay, mult = rewardLawyer(lawyerSrc, suspectStars)
    persistLawyerCooldown(identifier, now)

    if newStars <= 0 then
        clearWanted(suspectSrc)
    else
        setStars(suspectSrc, newStars, 'Obhajoba')
    end

    TriggerClientEvent('kg_wanted:lawyerBig', lawyerSrc, pay, removed, newStars, mult)
    TriggerClientEvent('ox_lib:notify', suspectSrc, {
        type = 'success',
        description = ('Právník ti upravil wanted (%d★ → %d★).'):format(suspectStars, newStars)
    })
end)

RegisterNetEvent('kg_wanted:policeDutyToggle', function(makeOnDuty)
    local src = source
    makeOnDuty = makeOnDuty == true

    local xPlayer = ESX.GetPlayerFromId(src)
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
            setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
        end)
    else
        xPlayer.setJob(Config.UnemployedJob, 0)
        Player(src).state.kg_police_duty = false
        TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Ukončil jsi službu.' })

        setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
    end
end)

CreateThread(function()
    if not (Config.PoliceDuty and Config.PoliceDuty.Enabled and Config.PoliceDuty.EnforceStationOnly) then return end
    while true do
        Wait((tonumber(Config.PoliceDuty.EnforceCheckSeconds) or 10) * 1000)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and isPolice(xPlayer) then
                local onDuty = Player(src).state.kg_police_duty == true
                if not onDuty then
                    xPlayer.setJob(Config.UnemployedJob, 0)
                    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Police job lze pouze přes nástup na stanici.' })
                    setStatebags(src, tonumber(Player(src).state.kg_wanted or 0) or 0, tostring(Player(src).state.kg_wanted_reason or '') or '')
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local entry = Wanted[src]
    if entry and entry.identifier and entry.identifier ~= '' then
        persistWanted(entry.identifier, entry.stars or 0, entry.lastReason or '')
    end
    Wanted[src] = nil
    HurtCooldown[src] = nil
end)

-- ✅ Player loaded -> load wanted from DB + set job flags
RegisterNetEvent('esx:playerLoaded', function(playerId)
    local src = playerId or source
    local entry = ensureEntry(src)

    local identifier = getIdentifier(src) or entry.identifier
    entry.identifier = identifier or ''

    Player(src).state.kg_police_duty = false

    if not (Config.Persistence and Config.Persistence.Enabled) then
        setStatebags(src, entry.stars or 0, entry.lastReason or '')
        return
    end

    loadWanted(entry.identifier, function(stars, reason)
        entry.stars = clamp(stars or 0, 0, Config.MaxStars)
        entry.lastReason = reason or ''
        entry.lastUpdate = os.time()
        setStatebags(src, entry.stars, entry.lastReason)
    end)
end)

-- ✅ IMPORTANT FIX:
-- ESX calls: TriggerEvent('esx:setJob', playerId, job, lastJob)
-- If we catch it with wrong signature, "job" becomes number (playerId) -> crashes.
AddEventHandler('esx:setJob', function(playerId, job, lastJob)
    if type(playerId) ~= 'number' then return end
    if type(job) ~= 'table' then return end

    local src = playerId

    -- update job flags immediately for client filtering
    local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
    local reason = tostring(Player(src).state.kg_wanted_reason or '') or ''
    setStatebags(src, stars, reason)
end)
