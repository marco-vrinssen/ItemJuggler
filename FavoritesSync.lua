-- Sync auction house and crafting order favorites across all characters
--
-- Account DB (MyTemsFavoritesDB) is the single source of truth.
-- Per-character DB (MyTemsFavoritesCharDB) stores a snapshot of what was
-- last synced, plus an initialized flag.
--
-- First session:  Push account favorites to character, then discover
--                 pre-existing character favorites via browse results
--                 and merge them into the account DB.
-- Later sessions: Two-way diff against the snapshot to propagate adds
--                 and removals made on other characters.

local ADDON_NAME = "MyTems"
local accountDB, characterDB
local syncing = false

----------------------------------------------------------------
-- Item key handling
----------------------------------------------------------------

local KEY_FIELDS = {"itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID", "itemContext"}

local function CopyItemKey(itemKey)
    local copy = {}
    for _, field in ipairs(KEY_FIELDS) do
        copy[field] = itemKey[field] or 0
    end
    return copy
end

local function SerializeItemKey(itemKey)
    local parts = {}
    for i, field in ipairs(KEY_FIELDS) do
        parts[i] = tostring(itemKey[field] or 0)
    end
    return table.concat(parts, ":")
end

----------------------------------------------------------------
-- Chat notifications
----------------------------------------------------------------

local function GetItemLink(itemKey)
    if itemKey.itemID and itemKey.itemID ~= 0 then
        local _, link = C_Item.GetItemInfo(itemKey.itemID)
        if link then return link end
        C_Item.RequestLoadItemDataByID(itemKey.itemID)
        return "|cff9d9d9d[Item " .. itemKey.itemID .. "]|r"
    end
    return "|cff9d9d9d[Unknown]|r"
end

local function Notify(added, itemKey)
    local prefix = added and "|cff00ff00[+]|r " or "|cffff0000[-]|r "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. GetItemLink(itemKey))
    end
end

----------------------------------------------------------------
-- Hook: capture user-initiated favorite changes in real time
----------------------------------------------------------------

hooksecurefunc(C_AuctionHouse, "SetFavoriteItem", function(itemKey, isFavorite)
    if syncing or not accountDB or not characterDB then return end
    local key = SerializeItemKey(itemKey)
    local copy = CopyItemKey(itemKey)
    if isFavorite then
        accountDB.favorites[key] = copy
        characterDB.snapshot[key] = copy
    else
        accountDB.favorites[key] = nil
        characterDB.snapshot[key] = nil
    end
    Notify(isFavorite, itemKey)
end)

----------------------------------------------------------------
-- Discover pre-existing favorites from browse results
-- Used during first session to merge character favorites
-- into account DB before the character is marked initialized
----------------------------------------------------------------

local function DiscoverFavorite(itemKey)
    if not itemKey or not accountDB or not characterDB then return end
    if not C_AuctionHouse.IsFavoriteItem(itemKey) then return end
    local key = SerializeItemKey(itemKey)
    if accountDB.favorites[key] then return end
    local copy = CopyItemKey(itemKey)
    accountDB.favorites[key] = copy
    characterDB.snapshot[key] = copy
end

----------------------------------------------------------------
-- Sync favorites between account DB and character
----------------------------------------------------------------

local function SyncFavorites()
    if not accountDB or not characterDB then return end
    syncing = true

    if not characterDB.initialized then
        -- First session for this character
        -- Push all account favorites to character

        for key, itemKey in pairs(accountDB.favorites) do
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            characterDB.snapshot[key] = CopyItemKey(itemKey)
            Notify(true, itemKey)
        end

        syncing = false

        -- Search favorites to trigger browse results so DiscoverFavorite
        -- can find this character's pre-existing favorites and merge them

        C_AuctionHouse.SearchForFavorites({})
        return
    end

    -- Subsequent sessions: two-way diff against snapshot
    local changed = false

    -- Items in account DB but not in snapshot: added on another character

    for key, itemKey in pairs(accountDB.favorites) do
        if not characterDB.snapshot[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            characterDB.snapshot[key] = CopyItemKey(itemKey)
            Notify(true, itemKey)
            changed = true
        end
    end

    -- Items in snapshot but not in account DB: removed on another character

    for key, itemKey in pairs(characterDB.snapshot) do
        if not accountDB.favorites[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, false)
            characterDB.snapshot[key] = nil
            Notify(false, itemKey)
            changed = true
        end
    end

    syncing = false
    if changed then
        C_AuctionHouse.SearchForFavorites({})
    end
end

----------------------------------------------------------------
-- Event handling
----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            MyTemsFavoritesDB = MyTemsFavoritesDB or {}
            accountDB = MyTemsFavoritesDB
            accountDB.favorites = accountDB.favorites or {}

            MyTemsFavoritesCharDB = MyTemsFavoritesCharDB or {}
            characterDB = MyTemsFavoritesCharDB
            characterDB.snapshot = characterDB.snapshot or {}
        elseif addon == "Blizzard_ProfessionsCustomerOrders" then
            if ProfessionsCustomerOrdersFrame then
                ProfessionsCustomerOrdersFrame:HookScript("OnShow", SyncFavorites)
            end
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        SyncFavorites()
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        -- Mark initialized after first AH session completes
        -- so future sessions use two-way diff instead of merge

        if characterDB and not characterDB.initialized then
            characterDB.initialized = true
        end
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    -- Scan browse results to discover favorites not yet in account DB

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
            DiscoverFavorite(result.itemKey)
        end
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        local results = ...
        if results then
            for _, result in ipairs(results) do
                DiscoverFavorite(result.itemKey)
            end
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        if itemID then
            DiscoverFavorite(C_AuctionHouse.MakeItemKey(itemID))
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        if itemKey then
            DiscoverFavorite(itemKey)
        end
        return
    end
end)
