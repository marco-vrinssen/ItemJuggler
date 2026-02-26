-- [enable spacebar auction posting and default to current expansion filter]

local AuctionFrame = CreateFrame("Frame")
local isPostEnabled = false

local function PostAuction()
    if not isPostEnabled or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        return
    end
    local sellFrames = {
        AuctionHouseFrame.CommoditiesSellFrame,
        AuctionHouseFrame.ItemSellFrame,
        AuctionHouseFrame.SellFrame,
    }
    for _, sellFrame in ipairs(sellFrames) do
        if sellFrame and sellFrame:IsShown() and sellFrame.PostButton and sellFrame.PostButton:IsEnabled() then
            sellFrame.PostButton:Click()
            return
        end
    end
end

AuctionFrame:RegisterEvent("ADDON_LOADED")
AuctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
AuctionFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
AuctionFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_AuctionHouseUI" then
            if AUCTION_HOUSE_DEFAULT_FILTERS then
                AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        isPostEnabled = true
        self:SetScript("OnKeyDown", function(self, key)
            if key == "SPACE" and isPostEnabled then
                PostAuction()
                self:SetPropagateKeyboardInput(false)
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        self:SetPropagateKeyboardInput(true)
        self:EnableKeyboard(true)
        self:SetFrameStrata("HIGH")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        isPostEnabled = false
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
    end
end)
