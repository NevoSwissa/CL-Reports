local QBCore = exports['qb-core']:GetCoreObject()

local receiveReports = false

local enableReportUI = false

local enableAdminUI = false

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
                    PlaySoundFrontend(-1, "NO", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                    TriggerServerEvent("CL-Reports:ButtonAction", "bring", result, data.reportid)
                elseif data.action == "goto" then
                    PlaySoundFrontend(-1, "NO", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                    TriggerServerEvent("CL-Reports:ButtonAction", "goto", result, data.reportid)
                elseif data.action == "resolve" then
                    TriggerServerEvent("CL-Reports:ResolveReport", data.reportid, result)
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

RegisterNUICallback("GetReportStatus", function(data, cb)
    QBCore.Functions.TriggerCallback('CL-Reports:GetInfo', function(result)
        cb(result)
    end, { type = "reportstatus", playerid = data.playerid })
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

RegisterKeyMapping("reportissue", 'Reports System', 'keyboard', '9')

RegisterKeyMapping("adminconsole", 'Reports Admin Console', 'keyboard', 'h')

RegisterCommand("adminconsole", function()
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
                enableAdminUI = false
            end
        end, { type = "admin" })
    else
        SetNuiFocus(false, false)
    end
end)

RegisterCommand("reportissue", function()
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