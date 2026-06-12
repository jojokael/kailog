local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer.Name

local WEBHOOK_URL = "https://discord.com/api/webhooks/1466869016327884853/dBMaFCOuff_H4aiEbtjnmQ6Z7B1YcE8EIEWvem5UYWWfmW8gBDh6PQu5gf8S5PZLks-G"
local MY_DISCORD_ID = "200729982354456577" -- Seni etiketleyecek Discord ID
local AUTO_SEND_RESULTS = true

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
local lastResultsSentTick = 0
local lastGameResults = nil

local function isEndScreenVisible()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return false end
    local gg = gui:FindFirstChild("GameGui")
    if not gg then return false end
    local es = gg:FindFirstChild("EndScreen")
    return es and es.Visible == true
end

local function getGameResult()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return "UNKNOWN" end
    local gg = gui:FindFirstChild("GameGui")
    if not gg then return "UNKNOWN" end
    local es = gg:FindFirstChild("EndScreen")
    if not es then return "UNKNOWN" end
    local c = es:FindFirstChild("Content")
    if not c then return "UNKNOWN" end
    local t = c:FindFirstChild("Title")
    return t and t.Text or "UNKNOWN"
end

local function scanRewards()
    local rewards = {}
    pcall(function()
        local rf = LocalPlayer.PlayerGui.GameGui.EndScreen.Rewards
        for _, child in ipairs(rf:GetChildren()) do
            if child:IsA("ImageLabel") and child.Visible then
                local amt = "1"
                local al = child:FindFirstChild("Amount")
                if al and al:IsA("TextLabel") then amt = al.Text end
                
                if child.Name == "DroppedTower" then
                    -- 👤 ÜNİTE TARAMA ALANI (Görünürlük kilidi kaldırıldı, kaçırma ihtimali sıfır)
                    for _, tower in ipairs(child:GetChildren()) do
                        if tower:IsA("ImageLabel") then 
                            local cm = tower:FindFirstChild("Checkmark")
                            -- Checkmark açık ise VEYA şans metni varsa ünite alınmıştır
                            local obtained = (cm and cm.Visible) or true 
                            local cl = tower:FindFirstChild("Chance")
                            
                            table.insert(rewards, { 
                                type = "TowerDrop", 
                                name = tower.Name, 
                                chance = cl and cl.Text or "?", 
                                obtained = obtained 
                            })
                        end
                    end
                else
                    table.insert(rewards, { type = "Reward", name = child.Name, amount = amt })
                end
            end
        end
    end)
    
    local stats = {}
    pcall(function()
        local sf = LocalPlayer.PlayerGui.GameGui.EndScreen.Stats
        local w = sf:FindFirstChild("Wave"); if w then stats.waves = w.Text end
        local m = sf:FindFirstChild("Money"); if m and m.Visible then stats.money = m.Text end
    end)
    return { result = getGameResult(), rewards = rewards, stats = stats, timestamp = os.date("%Y-%m-%d %H:%M:%S"), player = Username }
end

local function sendWebhook(url, payload)
    if not httpRequest or url == "" then return false end
    local ok = pcall(function() 
        httpRequest({ 
            Url = url, 
            Method = "POST", 
            Headers = {["Content-Type"] = "application/json"}, 
            Body = HttpService:JSONEncode(payload) 
        }) 
    end)
    return ok
end

local function sendResultsToWebhook(url, results)
    if not results then return false end
    if tick() - lastResultsSentTick < 10 then return false end
    lastResultsSentTick = tick()

    local currencies, items, towerDrops = {}, {}, {}
    local totalCurrencies = {}
    local detailsForNotification = {}
    local shouldMention = false

    for _, r in ipairs(results.rewards or {}) do
        if r.type == "TowerDrop" then
            table.insert(towerDrops, string.format("👤 **%s** (%s) - %s", r.name, r.chance, r.obtained and "**KAZANILDI**" or "ıskalandı"))
            
            -- ÜNİTE DÜŞTÜYSE ANINDA ETİKETİ ÇAK!
            shouldMention = true
            table.insert(detailsForNotification, r.name)
        else
            local amt = tonumber(r.amount)
            local lowerName = string.lower(r.name)
            
            -- Eğer düşen şey gold, coins veya gems DEĞİLSE (Megumi, Kasa vb. ise) ETİKETLE!
            if not (string.find(lowerName, "gem") or string.find(lowerName, "gold") or string.find(lowerName, "coin")) then
                shouldMention = true
                table.insert(detailsForNotification, string.format("%s (x%s)", r.name, r.amount))
            end

            -- Log tablosuna ekleme (Sorunsuz eski mantık)
            if amt and amt > 1 then
                table.insert(currencies, string.format("%s: **%s**", r.name, r.amount))
                totalCurrencies[r.name] = (totalCurrencies[r.name] or 0) + amt
            else
                table.insert(items, string.format("%s x%s", r.name, r.amount))
            end
        end
    end

    local totalLines = {}
    for name, total in pairs(totalCurrencies) do
        table.insert(totalLines, string.format("%s: **%d**", name, total))
    end

    local balanceLines = {}
    pcall(function()
        for _, child in ipairs(LocalPlayer:GetChildren()) do
            if child:IsA("IntValue") or child:IsA("NumberValue") then
                local val = child.Value
                if val and val ~= 0 then
                    table.insert(balanceLines, string.format("%s: **%s**", child.Name, tostring(val)))
                end
            end
        end
    end)

    local spoilerUser = "||" .. (results.player or Username) .. "||"

    local fields = {
        { name = "Result", value = results.result or "Unknown", inline = true },
        { name = "Waves", value = (results.stats and results.stats.waves) or "?", inline = true },
        { name = "Player", value = spoilerUser, inline = true },
    }
    if #currencies > 0 then table.insert(fields, { name = "Earned", value = table.concat(currencies, "\n"), inline = true }) end
    if #items > 0 then table.insert(fields, { name = "Items", value = table.concat(items, "\n"), inline = true }) end
    if #towerDrops > 0 then table.insert(fields, { name = "Tower Drops", value = table.concat(towerDrops, "\n"), inline = false }) end
    if #currencies == 0 and #items == 0 and #towerDrops == 0 then table.insert(fields, { name = "Rewards", value = "None", inline = false }) end
    if #totalLines > 0 then table.insert(fields, { name = "Totals (this game)", value = table.concat(totalLines, "\n"), inline = true }) end
    if #balanceLines > 0 then table.insert(fields, { name = "Current Balances", value = table.concat(balanceLines, "\n"), inline = true }) end

    local embedColor = (string.find(string.lower(results.result), "vic") or string.find(string.lower(results.result), "win")) and 0x008B8B or 0xFF8C00
    
    -- Bildirim Metni
    local contentStr = ""
    if shouldMention then
        contentStr = string.format("<@%s> 🚨 **YENİ UNIT VEYA ÖZEL EŞYA DÜŞTÜ:** `%s`", MY_DISCORD_ID, table.concat(detailsForNotification, ", "))
    else
        contentStr = "ℹ️ **Sessiz Maç Sonu Logu (Coins/Gems)**"
    end

    return sendWebhook(url, { 
        content = contentStr,
        embeds = {{ 
            title = "Sorcerer Tower Defense - Game Results", 
            color = embedColor, 
            fields = fields, 
            -- 🎯 ARTIK BURADA GÜNCEL SÜRÜM YAZIYOR:
            footer = { text = "Judas v2.8 | Tam Fix Sürümü | " .. (results.timestamp or "") } 
        }} 
    })
end

task.spawn(function()
    local lastState = false
    while task.wait(1) do
        local visible = isEndScreenVisible()
        
        if visible and not lastState then
            task.wait(1.5)
            lastGameResults = scanRewards()

            if AUTO_SEND_RESULTS and WEBHOOK_URL ~= "" and WEBHOOK_URL ~= "YOUR_WEBHOOK_URL_HERE" then
                local ok = sendResultsToWebhook(WEBHOOK_URL, lastGameResults)
            end
        end
        lastState = visible
    end
end)
