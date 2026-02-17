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
                                KGW.drawText3D(c.x, c.y, c.z + 1.05, ('WANTED %s'):format(string.rep('★', stars)))
                            end
                        end
                    end
                end
            end
        end
    end
end)
