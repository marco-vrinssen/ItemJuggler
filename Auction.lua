local postFrame = CreateFrame("Frame")
local postEnabled = false

local function postAuction()
    if not postEnabled or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    local frames = {AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.ItemSellFrame, AuctionHouseFrame.SellFrame}
    for _, fr in ipairs(frames) do
        if fr and fr:IsShown() and fr.PostButton and fr.PostButton:IsEnabled() then
            fr.PostButton:Click()
            return
        end
    end
end

postFrame:RegisterEvent("ADDON_LOADED")
postFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
postFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
postFrame:SetScript("OnEvent", function(self, e, arg1)
    if e == "ADDON_LOADED" then
        if arg1 == "Blizzard_AuctionHouseUI" then
            if AUCTION_HOUSE_DEFAULT_FILTERS then
                AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end
    elseif e == "AUCTION_HOUSE_SHOW" then
        postEnabled = true
        self:SetScript("OnKeyDown", function(s, k)
            if k == "SPACE" and postEnabled then
                postAuction()
                s:SetPropagateKeyboardInput(false)
            else
                s:SetPropagateKeyboardInput(true)
            end
        end)
        self:SetPropagateKeyboardInput(true)
        self:EnableKeyboard(true)
        self:SetFrameStrata("HIGH")
    elseif e == "AUCTION_HOUSE_CLOSED" then
        postEnabled = false
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
    end
end)
