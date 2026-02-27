-- Enable spacebar auction posting and default to current expansion filter

local auctionFrm = CreateFrame("Frame")
local postEnabled = false

local function PostAuction()
    if not postEnabled or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
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

auctionFrm:RegisterEvent("ADDON_LOADED")
auctionFrm:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrm:RegisterEvent("AUCTION_HOUSE_CLOSED")
auctionFrm:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_AuctionHouseUI" then
            if AUCTION_HOUSE_DEFAULT_FILTERS then
                AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        postEnabled = true
        self:SetScript("OnKeyDown", function(self, key)
            if key == "SPACE" and postEnabled then
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
        postEnabled = false
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
    end
end)
