Config = {}

Config.Timeout = {
    Enable = true, -- Set to false to disable the cooldown system of which after X time the active report would get deleted.
    Time = 4, -- Time in minutes for the cooldown (If Enable)
}

Config.Discord = {
    Enable = true, -- Set to false to disable the use of discord logs
    Image = "https://cdn.discordapp.com/attachments/967914093396774942/1125782793570488360/CLOUD_LOGO.png", -- The image used in the discord logs
    Webhook = "https://discord.com/api/webhooks/1010869631692591206/AIUzNU4Hl_2wA9K_hU__I3oYrNqKptTMZeQ_gZA3AlhAj6nNs_w6idysZ-n5pzIUed8R", -- The discord webhook where the logs will be sent to
}