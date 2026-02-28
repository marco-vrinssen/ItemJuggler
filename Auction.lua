-- Spacebar auction posting and default current expansion filter

local auctionFrame = CreateFrame("Frame")
local postEnabled = false

----------------------------------------------------------------
-- Posting
----------------------------------------------------------------

local function PostAuction()
    if not postEnabled then return end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end

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

----------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------

local function OnAddonLoaded(addonName)
    if addonName == "Blizzard_AuctionHouseUI" then
        if AUCTION_HOUSE_DEFAULT_FILTERS then
            AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        end
    end
end

local function OnAuctionHouseShow()
    postEnabled = true

    auctionFrame:SetScript("OnKeyDown", function(_, key)
        if key == "SPACE" and postEnabled then
            PostAuction()
            auctionFrame:SetPropagateKeyboardInput(false)
        else
            auctionFrame:SetPropagateKeyboardInput(true)
        end
    end)

    auctionFrame:SetPropagateKeyboardInput(true)
    auctionFrame:EnableKeyboard(true)
    auctionFrame:SetFrameStrata("HIGH")
end

local function OnAuctionHouseClosed()
    postEnabled = false
    auctionFrame:SetScript("OnKeyDown", nil)
    auctionFrame:EnableKeyboard(false)
end

----------------------------------------------------------------
-- Event registration
----------------------------------------------------------------

auctionFrame:RegisterEvent("ADDON_LOADED")
auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

auctionFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "AUCTION_HOUSE_SHOW" then
        OnAuctionHouseShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnAuctionHouseClosed()
    end
end)
