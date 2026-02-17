KGW = KGW or {}

local jailActive = false
local jailEndTime = 0

-- nouzové propuštění
RegisterNetEvent(KGW.Const.Events.ForceRelease, function()
    if not jailActive then return end
    jailEndTime = 0
end)

RegisterNetEvent(KGW.Const.Events.GoJail, function(minutes, data)
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

    KGW.UI.showBigWasted('~r~ZATCEN~s~', ('Zatkl te: ~w~%s~s~\nDoba: ~w~%d min~s~'):format(officer, minutes), 5000)

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
            lib.showTextUI(('Zbyvajici cas ve vezeni : %02d:%02d'):format(mm, ss), { position = 'bottom-center' })
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

    lib.notify({ type = 'success', description = 'Propusten.' })
end)
