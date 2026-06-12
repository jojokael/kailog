-- 🌀 ESKİ SCRIPTLERİ DURDURMA KİLİDİ
if _G.StopPreviousScanner then
    pcall(_G.StopPreviousScanner)
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer.Name
local lastResultsSentTick = 0
local running = true

_G.StopPreviousScanner = function()
    running = false
end

-- 🚫 SADECE BUNLAR DÜŞERSE ETİKET ATILMAYACAK (SESSİZCE LOGLANACAK)
local SILENT_LOG_ITEMS = {
    ["gems"] = true,
    ["coins"] = true,
    ["gold"] = true
}

-- Etiket tetiklenmeli mi kontrolünü yapan hassas fonksiyon
local function shouldTriggerMention(text)
    if not text or text == "" then return false end
    local cleanText = string.lower(text)
    local spaceStripped = string.gsub(cleanText, "%s+", "")
    
    -- Eğer düşen şey coins, gems veya gold ise etiket ATMA (false dön)
    if SILENT_LOG_ITEMS[cleanText] or SILENT_LOG_ITEMS[spaceStripped] then
        return false
    end
    
    -- Arayüzün kendi isimlerini yanlışlıkla etiketlemesin diye filtre
    local uiBypasses = {["uilistlayout"] = true, ["uipad"] = true, ["uicorner"] = true, ["uigradient"] = true, ["amount"] = true, ["rewards"] = true, ["droppedtower"] = true}
    if uiBypasses[cleanText] then return false end
    
    -- Geri kalan her şeyde (Megumi, Crates, Üniteler vb.) ETİKET AT!
    return true
end

local function sendWebhook(url, payload)
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not httpRequest or url == "" then return false end
    pcall(function() 
        httpRequest({ 
            Url = url, Method = "POST", 
            Headers = {["Content-Type"] = "application/json"}, 
            Body = HttpService:JSONEncode(payload) 
        }) 
    end)
end

-- 🛠️ YENİ NESİL RAPORLAMA MOTORU
local function checkEndScreenRewards()
    if tick() - lastResultsSentTick < 10 then return end
    lastResultsSentTick = tick()

    local shouldMentionUser = false
    local triggerReason = ""
    local itemsList = {}
    local unitsList = {}

    pcall(function()
        local endScreen = LocalPlayer.PlayerGui.GameGui.EndScreen
        
        -- 1. ADIM: Ekrandaki tüm yazıları ve objeleri etiket kontrolü için tara
        for _, obj in ipairs(endScreen:GetDescendants()) do
            local nameCheck = obj.Name
            local textCheck = (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text or ""
            
            if shouldTriggerMention(nameCheck) then
                shouldMentionUser = true
                triggerReason = nameCheck
            elseif shouldTriggerMention(textCheck) then
                shouldMentionUser = true
                triggerReason = textCheck
            end
        end

        -- 2. ADIM: Ödülleri listelere ayırarak ekle
        local rf = endScreen:FindFirstChild("Rewards")
        if rf then
            for _, child in ipairs(rf:GetChildren()) do
                if child:IsA("ImageLabel") and child.Visible then
                    local amt = child:FindFirstChild("Amount") and child.Amount.Text or "1"
                    
                    if child.Name == "DroppedTower" then
                        -- 👤 ÜNİTE DÜŞTÜYSE BURASI ÇALIŞIR
                        for _, tower in ipairs(child:GetChildren()) do
                            if tower:IsA("ImageLabel") and tower.Visible then
                                table.insert(unitsList, string.format("👤 **%s**", tower.Name))
                                -- Üniteler coins/gems olmadığı için HER HALÜKARDA etiket tetikler!
                                shouldMentionUser = true
                                triggerReason = "Ünite: " .. tower.Name
                            end
                        end
                    else
                        -- 📦 KASA VEYA PARALAR BURAYA EKLENİR
                        table.insert(itemsList, string.format("📦 %s x%s", child.Name, amt))
                        
                        -- Eğer düşen şey bir kasaysa (crates), coins/gems listesinde olmadığı için yine etiket tetikler!
                        if shouldTriggerMention(child.Name) then
                            shouldMentionUser = true
                            triggerReason = child.Name
                        end
                    end
                end
            end
        end
    end)

    -- Ekranda hiçbir veri yoksa boş mesaj gitmesin diye kes
    if #itemsList == 0 and #unitsList == 0 then
        lastResultsSentTick = 0
        return
    end

    -- Maç Durumu ve Renk Ayarları
    local waveText = "?"
    local resultText = "UNKNOWN"
    pcall(function()
        local es = LocalPlayer.PlayerGui.GameGui.EndScreen
        waveText = es.Stats.Wave.Text
        resultText = es.Content.Title.Text
    end)

    local embedColor = 16776960 -- Sarı
    local lowerResult = string.lower(resultText)
    if string.find(lowerResult, "victory") or string.find(lowerResult, "win") then embedColor = 65280 -- Yeşil
    elseif string.find(lowerResult, "defeat") or string.find(lowerResult, "lose") or string.find(lowerResult, "game over") then embedColor = 16711680 -- Kırmızı end

    -- 🎯 BİLDİRİM VE ETİKET SEÇİMİ
    local contentStr = ""
    if shouldMentionUser then
        contentStr = string.format("<@%s> 🚨 **ALARM! ÖNEMLİ ÖDÜL/ÜNİTE DÜŞTÜ: (%s)** 🚨", "200729982354456577", triggerReason)
    else
        contentStr = "ℹ️ **Sessiz Maç Sonu Logu (Coins/Gems)**"
    end

    local fields = {
        { name = "Result", value = resultText, inline = true },
        { name = "Waves", value = waveText, inline = true },
        { name = "Player", value = "||" .. Username .. "||", inline = true },
    }
    
    if #unitsList > 0 then table.insert(fields, { name = "👥 Düşen Üniteler (Units)", value = table.concat(unitsList, "\n"), inline = false }) end
    if #itemsList > 0 then table.insert(fields, { name = "📦 Düşen Eşyalar (Items)", value = table.concat(itemsList, "\n"), inline = false }) end

    sendWebhook("https://discord.com/api/webhooks/1466869016327884853/dBMaFCOuff_H4aiEbtjnmQ6Z7B1YcE8EIEWvem5UYWWfmW8gBDh6PQu5gf8S5PZLks-G", {
        content = contentStr,
        embeds = {{
            title = shouldMentionUser and "🔥 KRİTİK ALARM! | Judas v2.6" or "Sorcerer Tower Defense - Judas v2.6",
            color = embedColor,
            fields = fields,
            footer = { text = "Judas v2.6 | Ünite ve Kasa Alarm Sürümü | " .. os.date("%Y-%m-%d %H:%M:%S") }
        }}
    })
end

-- ============================================================
-- 🚀 GARANTİLİ SÜREKLİ TARAMA DÖNGÜSÜ
-- ============================================================
task.spawn(function()
    while task.wait(1) and running do
        pcall(function()
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            local gg = gui and gui:FindFirstChild("GameGui")
            local es = gg and gg:FindFirstChild("EndScreen")
            
            if es then
                checkEndScreenRewards()
            end
        end)
    end
end)

print("Judas v2.6 Başarıyla Kuruldu! Coins/Gems sessiz loglanacak; Ünite, Kasa ve Megumi anında etiket atacak!")
