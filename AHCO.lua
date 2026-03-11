-- Post auctions with spacebar and auto-set current expansion filter

local auctionFrame = CreateFrame("Frame")
local postEnabled = false
local auctionHouseHooked = false
local craftingOrdersHooked = false

-- Find the visible sell frame and click its post button
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

-- Hook the auction house search bar to always apply the current expansion filter
local function HookAuctionHouseFilter()
    if auctionHouseHooked then return end

    local searchBar = AuctionHouseFrame.SearchBar
    local searchBox = searchBar.SearchBox

    local function applyFilter()
        searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        searchBar:UpdateClearFiltersButton()
        searchBox:SetFocus()
    end

    searchBar:HookScript("OnShow", function() C_Timer.After(0, applyFilter) end)
    C_Timer.After(0, applyFilter)

    auctionHouseHooked = true
end

-- Hook the crafting orders search bar to always apply the current expansion filter
local function HookCraftingOrdersFilter()
    if craftingOrdersHooked then return end

    local filterDropdown = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar.FilterDropdown
    local searchBox = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar.SearchBox

    local function applyFilter()
        filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        filterDropdown:ValidateResetState()
        searchBox:SetFocus()
    end

    filterDropdown:HookScript("OnShow", function() C_Timer.After(0, applyFilter) end)
    C_Timer.After(0, applyFilter)

    craftingOrdersHooked = true
end

-- Bind spacebar to post while the auction house is open
local function OnAuctionHouseShow()
    postEnabled = true
    HookAuctionHouseFilter()

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

-- Unbind spacebar when the auction house closes
local function OnAuctionHouseClosed()
    postEnabled = false
    auctionFrame:SetScript("OnKeyDown", nil)
    auctionFrame:EnableKeyboard(false)
end

-- Register auction house and crafting orders lifecycle events
auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
auctionFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")

auctionFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        OnAuctionHouseShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnAuctionHouseClosed()
    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        HookCraftingOrdersFilter()
    end
end)
