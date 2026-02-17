local ESX = exports['es_extended']:getSharedObject()

local PlayerData = {}
local isPoliceCached = false
local isLawyerCached = false

local zoneBlips = {} -- [wantedSrc] = { radius = blip, center = blip }
local lastHurtReport = 0

local jailActive = false
local jailEndTime = 0

local function dbg(...)
    if Config.Debug then
        print('[KG_Wanted]', ...)
    end
end

local function refreshJobCache()
    local job = PlayerData and PlayerData.job and PlayerData.job.name or nil
    isPoliceCached = (job == Config.PoliceJob)
    isLawyerCached = (Config.Lawyer and Config.Lawyer.Enabled and job == (Config.Lawyer.JobName or 'lawyer'))
end

AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    refreshJobCache()
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
    refreshJobCache()
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(250) end
    PlayerData = ESX.GetPlayerData()
    refreshJobCache()
end)

-- Keep server updated with our position (for police zone)
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            TriggerServerEvent('kg_wanted:updatePos', { x = c.x, y = c.y, z = c.z })
        end
    end
end)

-- Crime detection (simple): detect player damage / kill and report to server
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4] == 1

    if not victim or not attacker then return end
    if not DoesEntityExist(victim) or not DoesEntityExist(attacker) then return end
    if not IsEntityAPed(victim) or not IsEntityAPed(attacker) then return end

    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)

    if victimPlayer == -1 or attackerPlayer == -1 then return end
    if attackerPlayer ~= PlayerId() then return end

    local victimSrc = GetPlayerServerId(victimPlayer)
    if victimSrc <= 0 then return end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local vCoords = GetEntityCoords(victim)
    local dist = #(myCoords - vCoords)

    if victimDied then
        TriggerServerEvent('kg_wanted:crime', { type = 'kill', victim = victimSrc, dist = dist })
    else
        local now = GetGameTimer()
        if now - lastHurtReport > 5000 then
            lastHurtReport = now
            TriggerServerEvent('kg_wanted:crime', { type = 'hurt', victim = victimSrc, dist = dist })
        end
    end
end)

-- 3D text helper
local function drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(1)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)
end

-- ✅ WANTED 3D text: visible to EVERYONE
CreateThread(function()
    while true do
        Wait(0)

        if not Config.Visibility.Show3D then
            Wait(500)
        else
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)

            for _, player in ipairs(GetActivePlayers()) do
                if player ~= PlayerId() then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesEntityExist(ped) then
                        local src = GetPlayerServerId(player)
                        local stars = Player(src).state.kg_wanted or 0

                        if stars and stars > 0 then
                            local c = GetEntityCoords(ped)
                            local dist = #(myCoords - c)
                            if dist <= (Config.Visibility.Show3DMaxDistance or 120.0) then
                                drawText3D(c.x, c.y, c.z + 1.05, ('WANTED %s'):format(string.rep('★', stars)))
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ✅ Lawyer highlight (arrow / marker) – ONLY for wanted player
CreateThread(function()
    while true do
        Wait(0)

        local myStars = tonumber(LocalPlayer.state.kg_wanted or 0) or 0
        if myStars <= 0 then
            Wait(750)
        else
            if not (Config.Lawyer and Config.Lawyer.Enabled and Config.Lawyer.Highlight and Config.Lawyer.Highlight.Enabled) then
                Wait(750)
            else
                local myPed = PlayerPedId()
                local myCoords = GetEntityCoords(myPed)
                local maxDist = tonumber(Config.Lawyer.Highlight.MaxDistance or 60.0) or 60.0

                for _, player in ipairs(GetActivePlayers()) do
                    if player ~= PlayerId() then
                        local ped = GetPlayerPed(player)
                        if ped ~= 0 and DoesEntityExist(ped) then
                            local src = GetPlayerServerId(player)

                            local isLawyer = Player(src).state.kg_isLawyer == true
                            local lawyerStars = tonumber(Player(src).state.kg_wanted or 0) or 0

                            if isLawyer and lawyerStars <= 0 then
                                local c = GetEntityCoords(ped)
                                local dist = #(myCoords - c)
                                if dist <= maxDist then
                                    local h = tonumber(Config.Lawyer.Highlight.Height or 1.15) or 1.15
                                    local markerType = tonumber(Config.Lawyer.Highlight.MarkerType or 2) or 2
                                    local scale = tonumber(Config.Lawyer.Highlight.Scale or 0.35) or 0.35

                                    DrawMarker(
                                        markerType,
                                        c.x, c.y, c.z + h,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        scale, scale, scale,
                                        0, 153, 255, 180,
                                        false, true, 2, false, nil, nil, false
                                    )

                                    if Config.Lawyer.Highlight.ShowText then
                                        drawText3D(c.x, c.y, c.z + (h + 0.35), '~b~PRÁVNÍK~s~')
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Police zones blips (police-only)
local function removeZoneBlip(src)
    local b = zoneBlips[src]
    if not b then return end
    if b.radius and DoesBlipExist(b.radius) then RemoveBlip(b.radius) end
    if b.center and DoesBlipExist(b.center) then RemoveBlip(b.center) end
    zoneBlips[src] = nil
end

local function upsertZoneBlip(wantedSrc, pos, stars)
    if not pos then return end

    local x, y, z = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0
    if Config.Visibility.ZoneRandomize then
        local r = Config.Visibility.ZoneRandomizeMeters or 60.0
        x = x + math.random(-r, r)
        y = y + math.random(-r, r)
    end

    zoneBlips[wantedSrc] = zoneBlips[wantedSrc] or {}

    if zoneBlips[wantedSrc].radius and DoesBlipExist(zoneBlips[wantedSrc].radius) then RemoveBlip(zoneBlips[wantedSrc].radius) end
    if zoneBlips[wantedSrc].center and DoesBlipExist(zoneBlips[wantedSrc].center) then RemoveBlip(zoneBlips[wantedSrc].center) end

    local radius = AddBlipForRadius(x, y, z, Config.Visibility.ZoneRadius or 220.0)
    SetBlipAlpha(radius, 90)

    local center = AddBlipForCoord(x, y, z)
    SetBlipSprite(center, 161)
    SetBlipScale(center, 0.8)
    SetBlipAsShortRange(center, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('WANTED %s'):format(string.rep('★', stars)))
    EndTextCommandSetBlipName(center)

    zoneBlips[wantedSrc].radius = radius
    zoneBlips[wantedSrc].center = center
end

RegisterNetEvent('kg_wanted:policeZones', function(payload)
    if not isPoliceCached then return end
    if type(payload) ~= 'table' then return end

    local alive = {}
    for _, item in ipairs(payload) do
        if item and item.src and item.stars and item.pos then
            alive[item.src] = true
            upsertZoneBlip(item.src, item.pos, item.stars)
        end
    end

    for src, _ in pairs(zoneBlips) do
        if not alive[src] then removeZoneBlip(src) end
    end
end)

-- ======== GTA BIG MESSAGE HELPERS ========
local function showBigWasted(title, subtitle, durationMs)
    durationMs = tonumber(durationMs) or 5000

    local scaleform = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
    PushScaleformMovieMethodParameterString(title)
    PushScaleformMovieMethodParameterString(subtitle)
    PushScaleformMovieMethodParameterInt(5)
    EndScaleformMovieMethod()

    local endTime = GetGameTimer() + durationMs
    while GetGameTimer() < endTime do
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        Wait(0)
    end

    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

RegisterNetEvent('kg_wanted:rewardBig', function(amount, mult)
    amount = tonumber(amount) or 0
    mult = tonumber(mult) or 1.0

    local title = '~b~ZLOCINEC DOPADEN~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Odmena: ~g~$%s~s~  ~b~(HAPPY HOUR x%s)~s~'):format(amount, mult)
        or  ('Odmena: ~g~$%s~s~'):format(amount)

    showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent('kg_wanted:lawyerBig', function(amount, removed, newStars, mult)
    amount = tonumber(amount) or 0
    removed = tonumber(removed) or 0
    newStars = tonumber(newStars) or 0
    mult = tonumber(mult) or 1.0

    local title = '~g~OBHAJOBA USPELA~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Sundano: ~w~%d★~s~ | Nove: ~w~%d★~s~\nOdmena: ~g~$%s~s~  ~b~(HAPPY HOUR x%s)~s~'):format(removed, newStars, amount, mult)
        or  ('Sundano: ~w~%d★~s~ | Nove: ~w~%d★~s~\nOdmena: ~g~$%s~s~'):format(removed, newStars, amount)

    showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent('kg_wanted:lawyerDenied', function(remainingSec)
    remainingSec = tonumber(remainingSec) or 0
    local mm = math.floor(remainingSec / 60)
    local ss = remainingSec % 60
    lib.notify({ type = 'error', description = ('Cooldown: %02d:%02d'):format(mm, ss) })
end)

RegisterNetEvent('kg_wanted:codexTop', function(data)
    data = data or {}
    local title = data.title or 'KODEX PORUSEN'
    local desc  = data.desc  or 'Porušil jsi kodex policie.'
    showBigWasted(('~r~%s~s~'):format(title), desc, 5000)
end)

-- ✅ nouzové propuštění
RegisterNetEvent('kg_wanted:forceRelease', function()
    if not jailActive then return end
    jailEndTime = 0
end)

-- ======== ox_target: police jail + lawyer request + police duty circle ========
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
                if not isPoliceCached then return false end
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

-- ======== JAIL (stejné jako dřív, včetně random cely) ========
RegisterNetEvent('kg_wanted:goJail', function(minutes, data)
    if not Config.Jail.Enabled then return end
    minutes = tonumber(minutes) or 2
    if minutes < 1 then minutes = 1 end
    data = data or {}

    local officer = data.officer or 'Policista'
    local cell = data.cell

    local dest
    if type(cell) == 'table' and cell.x and cell.y and cell.z then
        dest = vector4(cell.x + 0.0, cell.y + 0.0, cell.z + 0.0, (cell.w or 0.0) + 0.0)
    else
        dest = Config.Jail.JailCoords
        if Config.Jail.Cells and #Config.Jail.Cells > 0 then
            dest = Config.Jail.Cells[math.random(1, #Config.Jail.Cells)]
        end
    end

    showBigWasted('~r~ZATCEN~s~', ('Zatkl tě: ~w~%s~s~\nDoba: ~w~%d min~s~'):format(officer, minutes), 5000)

    local ped = PlayerPedId()
    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, true)
    SetEntityHeading(ped, dest.w or 0.0)

    ClearPedTasksImmediately(ped)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    if Config.Jail.FreezeInJail then
        FreezeEntityPosition(ped, true)
    end

    SetEntityInvincible(ped, true)
    SetPlayerInvincible(PlayerId(), true)

    jailActive = true
    jailEndTime = GetGameTimer() + (minutes * 60 * 1000)

    local lastUiUpdate = 0
    while jailActive and GetGameTimer() < jailEndTime do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)

        local now = GetGameTimer()
        if now - lastUiUpdate >= 250 then
            lastUiUpdate = now
            local remainingMs = jailEndTime - now
            local remainingSec = math.floor(remainingMs / 1000)
            local mm = math.floor(remainingSec / 60)
            local ss = remainingSec % 60
            lib.showTextUI(('Zbývající čas ve vězení : %02d:%02d'):format(mm, ss), { position = 'bottom-center' })
        end

        Wait(0)
    end

    jailActive = false
    lib.hideTextUI()

    if Config.Jail.FreezeInJail then
        FreezeEntityPosition(ped, false)
    end

    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)

    local rc = Config.Jail.ReleaseCoords
    SetEntityCoords(ped, rc.x, rc.y, rc.z, false, false, false, true)
    SetEntityHeading(ped, rc.w or 0.0)

    lib.notify({ type = 'success', description = 'Propuštěn.' })
end)
