local QBCore = exports['qb-core']:GetCoreObject()

local receiveReports = false

local enableReportUI = false

local enableAdminUI = false

local entityCoords = {}

RegisterNUICallback("HideUserInterface", function()
    if enableReportUI then
        SetNuiFocus(false, false)
        enableReportUI = false
    end
end)

RegisterNUICallback("HideAdminInterface", function()
    if enableAdminUI then
        SetNuiFocus(false, false)
        enableAdminUI = false
    end
end)

RegisterNUICallback("ReportInfo", function(data)
    QBCore.Functions.Notify('Your report has been submitted', 'success')
    TriggerServerEvent("CL-Reports:ReceiveReportData", data, receiveReports)
    Citizen.CreateThread(function()
        Citizen.Wait(200)
        QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function() end, { type = "currentreports", sync = true })
    end)
end)

RegisterNUICallback("SendNotify", function(data)
    QBCore.Functions.Notify(data.message, data.type)
end)

RegisterNUICallback("ReportTimeout", function()
    TriggerServerEvent("CL-Reports:DeleteAllReports")
end)

RegisterNUICallback("SetReceiveReports", function(data)
    receiveReports = data.receiveReports
end)

RegisterNUICallback("ButtonAction", function(data)
    if data.reportid ~= nil then
        QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
            if result then
                if data.action == "bring" then
                    local adminEntity = PlayerPedId()
                    local adminCoords = GetEntityCoords(adminEntity)
                    local adminHeading = GetEntityHeading(adminEntity)
                    local reporterEntity = GetPlayerPed(GetPlayerFromServerId(result))
                    if adminEntity == reporterEntity then
                        QBCore.Functions.Notify('You cant bring yourself.', 'error')
                        return
                    end
                    entityCoords[data.reportid] = {
                        adminCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(result))),
                        adminHeading = GetEntityHeading(GetPlayerPed(GetPlayerFromServerId(result))),
                        reporterCoords = GetEntityCoords(PlayerPedId()),
                        reporterHeading = GetEntityHeading(PlayerPedId())
                    }
                    if adminCoords and reporterEntity then
                        PlaySoundFrontend(-1, "NO", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                        SetEntityCoords(reporterEntity, adminCoords.x, adminCoords.y, adminCoords.z)
                        SetEntityHeading(reporterEntity, adminHeading)
                    end
                elseif data.action == "goto" then
                    local adminEntity = PlayerPedId()
                    local reporterEntity = GetPlayerPed(GetPlayerFromServerId(result))
                    local reporterCoords = GetEntityCoords(reporterEntity)
                    local reporterHeading = GetEntityHeading(reporterEntity)
                    if adminEntity == reporterEntity then
                        QBCore.Functions.Notify('You cant go to yourself.', 'error')
                        return
                    end
                    entityCoords[data.reportid] = {
                        adminCoords = GetEntityCoords(PlayerPedId()),
                        adminHeading = GetEntityHeading(PlayerPedId()),
                        reporterCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(result))),
                        reporterHeading = GetEntityHeading(GetPlayerPed(GetPlayerFromServerId(result)))
                    }
                    if reporterCoords and adminEntity then
                        PlaySoundFrontend(-1, "NO", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                        SetEntityCoords(adminEntity, reporterCoords.x, reporterCoords.y, reporterCoords.z)
                        SetEntityHeading(adminEntity, reporterHeading)
                    end
                elseif data.action == "resolve" then
                    local adminEntity = PlayerPedId()
                    if entityCoords[data.reportid] then
                        if entityCoords[data.reportid].adminCoords then
                            local originalCoords = entityCoords[data.reportid].adminCoords
                            local originalHeading = entityCoords[data.reportid].adminHeading
                            if originalCoords and adminEntity then
                                SetEntityCoords(adminEntity, originalCoords.x, originalCoords.y, originalCoords.z)
                                SetEntityHeading(adminEntity, originalHeading)
                            end
                        elseif entityCoords[data.reportid].reporterCoords then
                            local reporterEntity = GetPlayerPed(GetPlayerFromServerId(result))
                            local originalReporterCoords = entityCoords[data.reportid].reporterCoords
                            local originalReporterHeading = entityCoords[data.reportid].reporterHeading
                            if originalReporterCoords and reporterEntity then
                                SetEntityCoords(reporterEntity, originalReporterCoords.x, originalReporterCoords.y, originalReporterCoords.z)
                                SetEntityHeading(reporterEntity, originalReporterHeading)
                            end
                        end
                    end
                    TriggerServerEvent("CL-Reports:ResolveReport", data.reportid, result)
                    entityCoords[data.reportid] = nil
                    Citizen.CreateThread(function()
                        Citizen.Wait(200)
                        SendNUIMessage({ 
                            action = 'HideHelpInterface',
                        })
                        QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function() end, { type = "currentreports", sync = true })
                    end)
                else
                    QBCore.Functions.Notify('Unknown action', 'error')
                end
            end
        end, { type = "buttons", reportid = data.reportid })
    else
        QBCore.Functions.Notify('Error, report id is nil', 'error')
    end
end)

RegisterNUICallback("GetPermission", function(data, cb)
    QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
        if result then
            cb(result)
        end
    end, { type = "godpermission" })
end)

RegisterNUICallback("GetTopAdmins", function(data, cb)
    QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
        if result then
            cb(result)
        end
    end, { type = "topadmins" })
end)

RegisterNUICallback("GetReports", function(data, cb)
    QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
        if result then
            cb(result)
        end
    end, { type = "currentreports", sync = false })
end)

RegisterNetEvent('CL-Reports:RefreshReports', function(reports)
    SendNUIMessage({ 
        action = 'Refresh',
        activeReports = reports,
    })
end)

RegisterKeyMapping("openReportsSystem", 'Reports System', 'keyboard', '9')

RegisterKeyMapping("openAdminsConsole", 'Reports Admin Console', 'keyboard', 'h')

RegisterCommand("openAdminsConsole", function()
    enableAdminUI = not enableAdminUI
    if enableAdminUI then
        QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
            if result then
                SetNuiFocus(true, true)
                SendNUIMessage({ 
                    action = 'ShowAdminInterface',
                    playerName = result.playerName,
                    activeReports = result.activeReports,
                })
            else
                QBCore.Functions.Notify("You are not authorized to access the admin console.", "error")
                enableAdminUI = false
            end
        end, { type = "admin" })
    else
        SetNuiFocus(false, false)
    end
end)

RegisterCommand("openReportsSystem", function()
    enableReportUI = not enableReportUI
    if enableReportUI then
        QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
            if result then
                SendNUIMessage({
                    action = 'ShowUserInterface',
                    playerName = result.playername,
                    playerID = result.playerid,
                    timeout = Config.Timeout,
                })
                SetNuiFocus(true, true)
            else
                QBCore.Functions.Notify("An error occured, name couldnt be fetched", "error")
            end
        end, { type = "name"})
    else
        SetNuiFocus(false, false)
    end
end)