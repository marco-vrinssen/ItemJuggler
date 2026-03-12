local auctionFrame         = CreateFrame("Frame")
local postEnabled          = false
local auctionHouseHooked   = false
local craftingOrdersHooked = false
local searchHooked         = false


-- Click the visible sell frame's post button
local function PostAuction()
    if not postEnabled then return end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    local sellFrames = {
        AuctionHouseFrame.CommoditiesSellFrame,
        AuctionHouseFrame.ItemSellFrame,
        AuctionHouseFrame.SellFrame,
    }
    for _, sellFrame in ipairs(sellFrames) do
        if sellFrame and sellFrame:IsShown()
        and sellFrame.PostButton and sellFrame.PostButton:IsEnabled() then
            sellFrame.PostButton:Click()
            return
        end
    end
end


-- Always apply the current expansion filter on the AH search bar
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


-- Always apply the current expansion filter on the crafting orders search bar
local function HookCraftingOrdersFilter()
    if craftingOrdersHooked then return end
    local browseBar      = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar
    local filterDropdown = browseBar.FilterDropdown
    local searchBox      = browseBar.SearchBox
    local function applyFilter()
        filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        filterDropdown:ValidateResetState()
        searchBox:SetFocus()
    end
    filterDropdown:HookScript("OnShow", function() C_Timer.After(0, applyFilter) end)
    C_Timer.After(0, applyFilter)
    craftingOrdersHooked = true
end


-- Auto-trigger search when an item name is shift-click pasted into the search box
local function HookSearchBarBehavior()
    if searchHooked then return end
    if not AuctionHouseFrame or not AuctionHouseFrame.SearchBar then return end
    local searchBar = AuctionHouseFrame.SearchBar
    local searchBox = searchBar.SearchBox
    local lastText  = ""
    searchBox:HookScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        -- Shift-click paste: non-user-input with a multi-character jump
        if not userInput and text ~= "" and #text > #lastText + 1 then
            C_Timer.After(0.05, function()
                if AuctionHouseFrame and AuctionHouseFrame:IsShown()
                and searchBar.SearchButton and searchBar.SearchButton:IsEnabled() then
                    searchBar.SearchButton:Click()
                end
            end)
        end
        lastText = text or ""
    end)
    searchHooked = true
end


-- Bind spacebar to post and hook filters/search when the AH opens
local function OnAuctionHouseShow()
    postEnabled = true
    HookAuctionHouseFilter()
    HookSearchBarBehavior()
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


-- Unbind spacebar when the AH closes
local function OnAuctionHouseClosed()
    postEnabled = false
    auctionFrame:SetScript("OnKeyDown", nil)
    auctionFrame:EnableKeyboard(false)
end


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
