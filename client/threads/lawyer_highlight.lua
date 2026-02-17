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
                                        KGW.drawText3D(c.x, c.y, c.z + (h + 0.35), '~b~PRÁVNÍK~s~')
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
