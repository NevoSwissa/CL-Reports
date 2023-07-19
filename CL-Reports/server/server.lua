local QBCore = exports['qb-core']:GetCoreObject()

local activeReport = {}

local entityCoords = {}

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        GetWeeklyReset()
        MySQL.Async.execute('DELETE FROM cl_reports', {})
    end
end)

function ResetReportsCount()
    local admins = GetAdmins()
    for _, admin in ipairs(admins) do
        MySQL.Async.execute('UPDATE players SET reports = 0 WHERE citizenid = @citizenid', {
            ['@citizenid'] = admin.PlayerData.citizenid
        })
    end
end

function GetAdminReports(citizenid, callback)
    MySQL.Async.fetchScalar('SELECT IFNULL(SUM(reports), 0) FROM players WHERE citizenid = @citizenid', {
        ['@citizenid'] = citizenid
    }, function(result)
        local reports = tonumber(result) or 0
        callback(reports)
    end)
end

function GetDiscordUID(playerId)
    local playerIdentifiers = GetPlayerIdentifiers(playerId)
    local discordUID = nil
    for _, identifier in ipairs(playerIdentifiers) do
        if string.find(identifier, "discord:") then
            discordUID = string.sub(identifier, 9)
            break
        end
    end
    return discordUID
end

function GetWeeklyReset()
    MySQL.Async.fetchScalar('SELECT last_reset FROM cl_reports_reset LIMIT 1', {}, function(lastResetTimestamp)
        if lastResetTimestamp == nil then
            local currentTimestamp = os.time()
            MySQL.Async.execute('INSERT INTO cl_reports_reset (last_reset) VALUES (@timestamp)', {
                ['@timestamp'] = currentTimestamp
            })
        else
            local currentTimestamp = os.time()
            local timeSinceLastReset = currentTimestamp - lastResetTimestamp
            local weekInSeconds = 7 * 24 * 60 * 60
            
            if timeSinceLastReset >= weekInSeconds then
                local admins = GetAdmins()
                MySQL.Async.execute('UPDATE cl_reports_reset SET last_reset = @timestamp LIMIT 1', {
                    ['@timestamp'] = currentTimestamp
                })
                local message = "### This Week's Admin Champions:\n\n"
                table.sort(admins, function(a, b)
                    return GetAdminReports(b.PlayerData.citizenid) < GetAdminReports(a.PlayerData.citizenid)
                end)
                
                local adminCount = 0 
                local processedCount = 0

                for _, admin in ipairs(admins) do
                    GetAdminReports(admin.PlayerData.citizenid, function(reports)
                        if reports > 0 then
                            adminCount = adminCount + 1
                        end

                        processedCount = processedCount + 1
                        if processedCount == #admins then
                            adminCount = math.min(adminCount, 10)

                            if adminCount > 0 then
                                ProcessAdmins(admins, adminCount, message)
                            else
                                message = "*No admins have responded to reports this week.*"
                                SendDiscordLog(message)
                                ResetReportsCount()
                            end
                        end
                    end)
                end
            end
        end
    end)
end

function ProcessAdmins(admins, adminCount, message)
    local processedCount = 0

    local function ProcessAdmin(admin)
        GetAdminReports(admin.PlayerData.citizenid, function(reports)
            local discordUID = GetDiscordUID(admin.PlayerData.source)
            processedCount = processedCount + 1
            message = message .. " **" .. processedCount .. ". " .. (discordUID and "<@" .. discordUID .. ">" or "Not available") .. " with " .. reports .. " reports this week.** \n"

            if processedCount == adminCount then
                SendDiscordLog(message)
                ResetReportsCount()
            end
        end)
    end

    for i = 1, #admins do
        local admin = admins[i]
        GetAdminReports(admin.PlayerData.citizenid, function(reports)
            if reports > 0 then
                ProcessAdmin(admin)
            else
                processedCount = processedCount + 1
                if processedCount == adminCount then
                    SendDiscordLog(message)
                    ResetReportsCount()
                end
            end
        end)
    end
end

function GetAdmins()
    local admins = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if QBCore.Functions.HasPermission(v.PlayerData.source, 'admin') or IsPlayerAceAllowed(v.PlayerData.source, 'command') then
            table.insert(admins, v)
        end
    end
    return admins
end

function GetTopAdmins(callback)
    local admins = GetAdmins()
    local adminCount = 0
    local processedCount = 0
    local topAdmins = {}

    for _, admin in ipairs(admins) do
        GetAdminReports(admin.PlayerData.citizenid, function(reports)
            if reports > 0 then
                adminCount = adminCount + 1
                table.insert(topAdmins, { admin = admin, reports = reports })
            end

            processedCount = processedCount + 1
            if processedCount == #admins then
                adminCount = math.min(adminCount, 5)
                table.sort(topAdmins, function(a, b)
                    return b.reports < a.reports
                end)

                local result = {}
                for i = 1, adminCount do
                    local name = topAdmins[i].admin.PlayerData.charinfo.firstname .. " " .. topAdmins[i].admin.PlayerData.charinfo.lastname
                    table.insert(result, { adminName = name, reports = topAdmins[i].reports })
                end

                callback(result)
            end
        end)
    end
end

function SendDiscordLog(message)
    local embed = {
        {
            ["color"] = 12370112, 
            ["title"] = "CloudDevelopment Reports",
            ["description"] = message,
            ["url"] = "https://discord.gg/rp6ynCJTKK",
            ["footer"] = {
                ["text"] = "By CloudDevelopment",
                ["icon_url"] = Config.Discord['Image']
            },
            ["thumbnail"] = {
                ["url"] = Config.Discord['Image'],
            },
        }
    }
    PerformHttpRequest(Config.Discord['Webhook'], function(err, text, headers) end, 'POST', json.encode({username = 'CL-Reports', embeds = embed, avatar_url = Config.Discord['Image']}), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent("CL-Reports:DeleteAllReports", function()
    local src = source
    local reporterID = tostring(src)
    MySQL.Async.fetchAll('SELECT * FROM cl_reports WHERE JSON_EXTRACT(report_info, "$.reporterID") = @reporterID', {
        ['@reporterID'] = reporterID,
    }, function(result)
        if result then
            MySQL.Async.execute('DELETE FROM cl_reports WHERE JSON_EXTRACT(report_info, "$.reporterID") = @reporterID', {
                ['@reporterID'] = reporterID,
            }, function(rowsAffected)
                if rowsAffected > 0 then
                    activeReport[reporterID] = false
                    TriggerClientEvent("QBCore:Notify", src, "Your report has been removed due to timeout. You can now create another report")
                else
                    TriggerClientEvent("QBCore:Notify", src, "An error occurred while removing your active report.", "error", 5000)
                end
            end)
        end
    end)
end)

RegisterServerEvent("CL-Reports:ReceiveReportData", function(data, receiveReports)
    local reporterID = data.reporterID
    local reportDescription = data.reportDescription
    local reportTitle = data.reportTitle
    local reportReason = data.type
    local playerName = GetPlayerName(reporterID)
    local discordUID = GetDiscordUID(reporterID)

    local message = "**### " .. playerName .. " reported a " .. reportReason .. 
    "** **Reporter ID:** " .. reporterID .. "\n" ..
    "**Discord User:** " .. (discordUID and "<@" .. discordUID .. ">" or "Not available") .. "\n" ..
    "**Report Title:** " .. reportTitle .. "\n\n" ..
    "**Report Description:**\n" .. reportDescription

    local jsonReportData = json.encode({
        reporterID = reporterID,
        reportDescription = reportDescription,
        reportTitle = reportTitle,
        reportReason = reportReason,
        playerName = playerName,
    })

    MySQL.Async.execute('INSERT INTO cl_reports (report_info) VALUES (@reportInfo)', {
        ['@reportInfo'] = jsonReportData,
    })
    if Config.Timeout['Enable'] then
        activeReport[reporterID] = true
    end
    if Config.Discord['Enable'] then
        SendDiscordLog(message)
    end
    if receiveReports then
        local admins = GetAdmins()
        for _, admin in ipairs(admins) do
            TriggerClientEvent("QBCore:Notify", admin.PlayerData.source, playerName .. " reported a " .. reportReason .. " use your admin console to respond", "primary", 7500)
        end
    end
end)

RegisterServerEvent("CL-Reports:ResolveReport", function(reportid, playerSource)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local originalCoordsData = entityCoords[reportid]
    MySQL.Async.execute('DELETE FROM cl_reports WHERE id = @id', {
        ['@id'] = reportid,
    }, function(rowsChanged)
        if rowsChanged > 0 then
            if originalCoordsData and (originalCoordsData.type == "bring" or originalCoordsData.type == "goto") then
                if originalCoordsData.type == "bring" then
                    local reporterEntity = GetPlayerPed(playerSource)
                    SetEntityCoords(reporterEntity, originalCoordsData.reporterCoords)
                    SetEntityHeading(reporterEntity, originalCoordsData.reporterHeading - 180)
                elseif originalCoordsData.type == "goto" then
                    local adminEntity = GetPlayerPed(src)
                    SetEntityCoords(adminEntity, originalCoordsData.adminCoords)
                    SetEntityHeading(adminEntity, originalCoordsData.adminHeading - 180)
                end
            end
            if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
                if playerSource ~= src then
                    MySQL.Async.execute('UPDATE players SET reports = IFNULL(reports, 0) + 1 WHERE citizenid = @citizenid', {
                        ['@citizenid'] = Player.PlayerData.citizenid,
                    }, function(rowsChanged)
                        if rowsChanged == 0 then
                            MySQL.Async.execute('INSERT INTO players (citizenid, reports) VALUES (@citizenid, 1)', {
                                ['@citizenid'] = Player.PlayerData.citizenid,
                            })
                        end
                    end)
                end
            end
            if playerSource ~= nil then
                activeReport[playerSource] = false
                TriggerClientEvent("QBCore:Notify", playerSource, "Your report has been resolved.", "success")
            end
        else
            if playerSource ~= nil then
                TriggerClientEvent("QBCore:Notify", playerSource, "Failed to resolve your report.", "error")
            end
        end
        entityCoords[reportid] = nil
    end)
end)

RegisterServerEvent("CL-Reports:ButtonAction", function(type, reporterID, reportID)
    local src = source
    if src and reporterID then
        local adminEntity = GetPlayerPed(src)
        local reporterEntity = GetPlayerPed(reporterID)
        if type == "bring" then
            if not entityCoords[reportID] then 
                local adminCoords = GetEntityCoords(adminEntity)
                local adminHeading = GetEntityHeading(adminEntity)
                if adminEntity and reporterEntity then
                    entityCoords[reportID] = {
                        adminCoords = adminCoords,
                        adminHeading = adminHeading,
                        reporterCoords = GetEntityCoords(reporterEntity),
                        reporterHeading = GetEntityHeading(reporterEntity),
                        type = type,
                    }
                    TriggerClientEvent("QBCore:Notify", reporterID, "Admin brought you to their location to assist with your report")
                    SetEntityCoords(reporterEntity, adminCoords)
                    SetEntityHeading(reporterEntity, adminHeading - 180)
                end
            else
                TriggerClientEvent("QBCore:Notify", src, "You can only use one action (bring or goto) for this report.", "error")
            end
        elseif type == "goto" then
            if not entityCoords[reportID] then 
                local reporterCoords = GetEntityCoords(reporterEntity)
                local reporterHeading = GetEntityHeading(reporterEntity)
                if adminEntity and reporterEntity then
                    entityCoords[reportID] = {
                        adminCoords = GetEntityCoords(adminEntity),
                        adminHeading = GetEntityHeading(adminEntity),
                        reporterCoords = reporterCoords,
                        reporterHeading = reporterHeading,
                        type = type,
                    }
                    TriggerClientEvent("QBCore:Notify", reporterID, "Admin went to your location to assist with your report")
                    SetEntityCoords(adminEntity, reporterCoords)
                    SetEntityHeading(adminEntity, reporterHeading - 180)
                end
            else
                TriggerClientEvent("QBCore:Notify", src, "You can only use one action (bring or goto) for this report.", "error")
            end
        end
    end
end)

QBCore.Functions.CreateCallback("CL-Reports:GetInfo", function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if data.type == "name" then
        local name = Player.PlayerData.charinfo.firstname
        if name ~= nil then
            cb({playername = name, playerid = src})
        else
            TriggerClientEvent("QBCore:Notify", src, "An error occured, name = nil", "error")
        end
    elseif data.type == "admin" then
        local name = Player.PlayerData.charinfo.firstname
        if QBCore.Functions.HasPermission(Player.PlayerData.source, 'admin') or IsPlayerAceAllowed(Player.PlayerData.source, 'command') and name ~= nil then
            MySQL.Async.fetchAll('SELECT report_info, id FROM cl_reports', {}, function(result)
                local activeReports = {}
                for _, row in ipairs(result) do
                    local reportData = json.decode(row.report_info)
                    reportData.id = row.id
                    table.insert(activeReports, reportData)
                end
                cb({playerName = name, activeReports = activeReports})
            end)
        else
            cb(nil)
        end                
    elseif data.type == "buttons" then
        MySQL.Async.fetchAll('SELECT * FROM cl_reports WHERE id = @id', {
            ['@id'] = data.reportid,
        }, function(result)
            if result and #result > 0 then
                local json_data = json.decode(result[1].report_info)
                local reporter = QBCore.Functions.GetPlayer(json_data['reporterID'])
                if reporter ~= nil then
                    if json_data['reporterID'] == src then
                        TriggerClientEvent("QBCore:Notify", src, "You cant do actions on yourself.", "error")
                        return
                    end
                    cb(json_data['reporterID'])
                else
                    TriggerClientEvent("QBCore:Notify", src, "Player is offline", "error")
                end
            end
        end)
    elseif data.type == "currentreports" then
        MySQL.Async.fetchAll('SELECT report_info, id FROM cl_reports', {}, function(result)
            local activeReports = {}
            if result then
                for _, row in ipairs(result) do
                    local reportData = json.decode(row.report_info)
                    reportData.id = row.id
                    table.insert(activeReports, reportData)
                end
            end
            if data.sync then
                local admins = GetAdmins()
                for _, admin in ipairs(admins) do
                    TriggerClientEvent("CL-Reports:RefreshReports", admin.PlayerData.source, activeReports)
                end
            else
                cb(activeReports)
            end
        end)
    elseif data.type == "godpermission" then
        local isGod = QBCore.Functions.HasPermission(src, 'god') or IsPlayerAceAllowed(src, 'command')
        cb(isGod)
    elseif data.type == "topadmins" then
        GetTopAdmins(function(admins)
            cb(admins)
        end)
    elseif data.type == "reportstatus" then
        if activeReport[data.playerid] ~= nil then
            cb(activeReport[data.playerid])
        else
            cb(false)
        end
    end
end) 