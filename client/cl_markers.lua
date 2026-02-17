KGW = KGW or {}

local function drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(1)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)
end

CreateThread(function()
    while true do
        Wait(0)

        local myStars = tonumber(LocalPlayer.state.kg_wanted or 0) or 0
        if myStars <= 0 then
            Wait(500)
        else
            for _, player in ipairs(GetActivePlayers()) do
                if player ~= PlayerId() then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesEntityExist(ped) then
                        local sid = GetPlayerServerId(player)
                        if KGW.Client and KGW.Client.LawyerSet and KGW.Client.LawyerSet[sid] == true then
                            local c = GetEntityCoords(ped)

                            -- zelená šipka (marker)
                            DrawMarker(
                                2, -- marker type (arrow)
                                c.x, c.y, c.z + 1.35,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                0.25, 0.25, 0.25,
                                0, 255, 0, 200,
                                false, true, 2, false, nil, nil, false
                            )

                            -- text vedle (bez diakritiky)
                            drawText3D(c.x, c.y, c.z + 1.55, '~g~PRAVNIK~s~')
                        end
                    end
                end
            end
        end
    end
end)
