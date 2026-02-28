-- Auto sell junk and auto repair at merchants

local merchantFrame = CreateFrame("Frame")
local handled = false

----------------------------------------------------------------
-- Sell and repair
----------------------------------------------------------------

local function AutoSellAndRepair()
    if not MerchantFrame:IsShown() then return end

    -- Repair: guild bank first if available, otherwise personal funds
    if CanMerchantRepair() then
        RepairAllItems(CanGuildBankRepair())
    end

    -- Sell all junk via the dedicated API
    C_MerchantFrame.SellAllJunkItems()
end

----------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------

local function OnMerchantShow()
    if handled then return end
    handled = true
    C_Timer.After(0.2, AutoSellAndRepair)
end

local function OnMerchantClosed()
    handled = false
end

local function OnTradeTimerConfirm()
    C_Timer.After(0, function()
        local popup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
        if popup then
            StaticPopup_OnClick(popup, 1)
        end
    end)
end

----------------------------------------------------------------
-- Event registration
----------------------------------------------------------------

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
