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
