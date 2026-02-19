-- KG_Wanted/client/jail.lua

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

    KGW.showBigWasted('~r~ZATCEN~s~', ('Zatkl te: ~w~%s~s~\nDoba: ~w~%d min~s~'):format(officer, minutes), 5000)

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

    KGW.jailActive = true
    KGW.jailEndTime = GetGameTimer() + (minutes * 60 * 1000)

    local lastUiUpdate = 0
    while KGW.jailActive and GetGameTimer() < KGW.jailEndTime do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)

        local now = GetGameTimer()
        if now - lastUiUpdate >= 250 then
            lastUiUpdate = now
            local remainingMs = KGW.jailEndTime - now
            local remainingSec = math.floor(remainingMs / 1000)
            local mm = math.floor(remainingSec / 60)
            local ss = remainingSec % 60

            lib.showTextUI(('Zbývající čas ve vězení : %02d:%02d'):format(mm, ss), { position = 'bottom-center' })
        end

        Wait(0)
    end

    KGW.jailActive = false
    lib.hideTextUI()

    if Config.Jail.FreezeInJail then
        FreezeEntityPosition(ped, false)
    end

    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)

    local rc = Config.Jail.ReleaseCoords
    SetEntityCoords(ped, rc.x, rc.y, rc.z, false, false, false, true)
    SetEntityHeading(ped, rc.w or 0.0)

    -- ✅ důležité: server zruší persisted jail
    TriggerServerEvent('kg_wanted:jailFinished')

    lib.notify({ type = 'success', description = 'Propuštěn.' })
end)
