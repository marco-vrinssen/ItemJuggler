-- Automatically trigger auction house search when pasting or using SetText

local previousSearchText = ""

-- Execute the auction house search if the frame is open
local function TriggerAuctionSearch()
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    AuctionHouseFrame.SearchBar:StartSearch()
end

-- Search immediately when text is programmatically set via SetText
local function OnSearchBoxSetText(_, text)
    if text and text ~= "" then
        C_Timer.After(0, TriggerAuctionSearch)
    end
end

-- Detect pasted input by checking for multi-character text changes
local function OnSearchBoxTextChanged(self, isUserInput)
    local currentSearchText = self:GetText()

    if isUserInput and currentSearchText ~= "" and math.abs(#currentSearchText - #previousSearchText) > 1 then
        C_Timer.After(0, TriggerAuctionSearch)
    end

    previousSearchText = currentSearchText
end

-- Hook into the auction house search box once the UI loads
local auctionHouseLoadHandler = CreateFrame("Frame")

auctionHouseLoadHandler:RegisterEvent("ADDON_LOADED")

auctionHouseLoadHandler:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "Blizzard_AuctionHouseUI" then return end

    auctionHouseLoadHandler:UnregisterEvent("ADDON_LOADED")

    local searchBox = AuctionHouseFrame.SearchBar.SearchBox
    hooksecurefunc(searchBox, "SetText", OnSearchBoxSetText)
    searchBox:HookScript("OnTextChanged", OnSearchBoxTextChanged)
end)
