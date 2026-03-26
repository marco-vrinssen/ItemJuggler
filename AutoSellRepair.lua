-- Repair all equipped gear if the merchant supports repairs
local function RepairGear()
    if CanMerchantRepair() then RepairAllItems() end
end

-- Sell all junk items if the character has opted in to auto-selling
local function SellJunk()
    if C_MerchantFrame.IsSellAllJunkEnabled() then C_MerchantFrame.SellAllJunkItems() end
end

-- Confirm trade timer removal popups that appear when selling certain items
local function ConfirmTradeTimerRemoval()
    RunNextFrame(function()
        local popup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
        if popup then popup.button1:Click() end
    end)
end

-- Defer merchant automation to isolate addon taint from the Blizzard UI
local merchantEventFrame = CreateFrame("Frame")
merchantEventFrame:RegisterEvent("MERCHANT_SHOW")
merchantEventFrame:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
merchantEventFrame:SetScript("OnEvent", function(_, event)
    RunNextFrame(function()
        if event == "MERCHANT_SHOW" then
            RepairGear()
            SellJunk()
        else
            ConfirmTradeTimerRemoval()
        end
    end)
end)
