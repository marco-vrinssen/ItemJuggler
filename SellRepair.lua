-- Auto sell junk and auto repair on vendor visits

local merchantFrame = CreateFrame("Frame")
local handled = false

-- Repair using guild bank funds if available, then sell all junk
local function AutoSellAndRepair()
    if not MerchantFrame:IsShown() then return end

    if CanMerchantRepair() then
        RepairAllItems(CanGuildBankRepair())
    end

    C_MerchantFrame.SellAllJunkItems()
end

-- Run once per visit with a short delay to let the UI initialize
local function OnMerchantShow()
    if handled then return end
    handled = true
    C_Timer.After(0.1, AutoSellAndRepair)
end

-- Reset so the next vendor visit triggers again
local function OnMerchantClosed()
    handled = false
end

-- Auto-confirm the trade timer popup by clicking its button widget directly
local function OnTradeTimerConfirm()
    local popup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
    if popup and popup.button1 then
        popup.button1:Click()
    end
end

-- Register merchant lifecycle events
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_CLOSED")
merchantFrame:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")

merchantFrame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        OnMerchantClosed()
    elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
        OnTradeTimerConfirm()
    end
end)
