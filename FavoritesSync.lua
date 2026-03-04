-- Sync auction house and crafting order favorites across all characters
--
-- Account DB (MyTemsFavoritesDB) is the single source of truth.
-- Per-character DB (MyTemsFavoritesCharDB) stores snapshots of what was
-- last synced, plus initialized flags per system.
--
-- Auction house favorites use item keys (itemID/itemLevel/etc).
-- Crafting order favorites use recipe IDs (spellIDs).
-- Each system syncs independently with the same two-phase approach:
--
-- First session:  Push account favorites to character, then discover
--                 pre-existing character favorites and merge them.
-- Later sessions: Two-way diff against the snapshot to propagate adds
--                 and removals made on other characters.

local ADDON_NAME = "MyTems"
local accountDB, characterDB
local syncing = false
local orderSyncing = false

----------------------------------------------------------------
-- Item key handling (auction house)
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

local function GetRecipeLink(recipeID)
    if not recipeID then return "|cff9d9d9d[Unknown Recipe]|r" end
    if C_Spell and C_Spell.GetSpellLink then
        local link = C_Spell.GetSpellLink(recipeID)
        if link then return link end
    end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(recipeID)
        if name then return "|cffffd100[" .. name .. "]|r" end
    end
    return "|cff9d9d9d[Recipe " .. recipeID .. "]|r"
end

local function Notify(added, displayLink)
    local prefix = added and "|cff00ff00[+]|r " or "|cffff0000[-]|r "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. displayLink)
    end
end

----------------------------------------------------------------
-- Auction house: hook user-initiated favorite changes
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
    Notify(isFavorite, GetItemLink(itemKey))
end)

----------------------------------------------------------------
-- Auction house: discover pre-existing favorites from browse results
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
-- Auction house: sync favorites between account DB and character
----------------------------------------------------------------

local function SyncFavorites()
    if not accountDB or not characterDB then return end
    syncing = true

    if not characterDB.initialized then
        for key, itemKey in pairs(accountDB.favorites) do
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            characterDB.snapshot[key] = CopyItemKey(itemKey)
            Notify(true, GetItemLink(itemKey))
        end
        syncing = false
        C_AuctionHouse.SearchForFavorites({})
        return
    end

    local changed = false

    for key, itemKey in pairs(accountDB.favorites) do
        if not characterDB.snapshot[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            characterDB.snapshot[key] = CopyItemKey(itemKey)
            Notify(true, GetItemLink(itemKey))
            changed = true
        end
    end

    for key, itemKey in pairs(characterDB.snapshot) do
        if not accountDB.favorites[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, false)
            characterDB.snapshot[key] = nil
            Notify(false, GetItemLink(itemKey))
            changed = true
        end
    end

    syncing = false
    if changed then
        C_AuctionHouse.SearchForFavorites({})
    end
end

----------------------------------------------------------------
-- Crafting orders: detect favorite API at runtime
----------------------------------------------------------------

local orderSetFav      -- function(recipeID, isFavorite)
local orderCheckFav    -- function(recipeID) -> bool
local orderSetFavName  -- string key for hooksecurefunc
local orderHasAPI = false

local function DetectCraftingOrderAPI()
    if not C_CraftingOrders then return false end

    -- Detect the set-favorite function

    local setNames = {
        "SetCustomerOptionFavorited",
        "SetCustomerOptionFavorite",
        "SetFavoriteCustomerOption",
    }
    for _, name in ipairs(setNames) do
        if type(C_CraftingOrders[name]) == "function" then
            orderSetFav = C_CraftingOrders[name]
            orderSetFavName = name
            break
        end
    end

    -- If no single function, check split Favorite/Unfavorite pattern

    if not orderSetFav then
        local favNames = {
            {"FavoriteCustomerOption", "UnfavoriteCustomerOption"},
            {"AddCustomerOptionFavorite", "RemoveCustomerOptionFavorite"},
        }
        for _, pair in ipairs(favNames) do
            local fav, unfav = C_CraftingOrders[pair[1]], C_CraftingOrders[pair[2]]
            if type(fav) == "function" and type(unfav) == "function" then
                orderSetFav = function(recipeID, isFavorite)
                    if isFavorite then fav(recipeID) else unfav(recipeID) end
                end
                -- Hook both: we'll set up hooks separately for split pattern
                orderSetFavName = pair[1]
                hooksecurefunc(C_CraftingOrders, pair[2], function(recipeID)
                    if orderSyncing or not accountDB or not characterDB then return end
                    local key = tostring(recipeID)
                    accountDB.orderFavorites[key] = nil
                    characterDB.orderSnapshot[key] = nil
                    Notify(false, GetRecipeLink(recipeID))
                end)
                break
            end
        end
    end

    -- Detect the check-favorite function

    local checkNames = {
        "IsCustomerOptionFavorited",
        "IsCustomerOptionFavorite",
        "IsFavoriteCustomerOption",
    }
    for _, name in ipairs(checkNames) do
        if type(C_CraftingOrders[name]) == "function" then
            orderCheckFav = C_CraftingOrders[name]
            break
        end
    end

    orderHasAPI = orderSetFav ~= nil
    return orderHasAPI
end

----------------------------------------------------------------
-- Crafting orders: hook user-initiated favorite changes
----------------------------------------------------------------

local function HookCraftingOrderFavorites()
    if not orderHasAPI or not orderSetFavName then return end

    hooksecurefunc(C_CraftingOrders, orderSetFavName, function(recipeID, isFavorite)
        if orderSyncing or not accountDB or not characterDB then return end

        -- For single-function pattern, isFavorite is the bool
        -- For split pattern (FavoriteCustomerOption), this hook only catches adds

        local added = isFavorite ~= false
        local key = tostring(recipeID)
        if added then
            accountDB.orderFavorites[key] = recipeID
            characterDB.orderSnapshot[key] = recipeID
        else
            accountDB.orderFavorites[key] = nil
            characterDB.orderSnapshot[key] = nil
        end
        Notify(added, GetRecipeLink(recipeID))
    end)
end

----------------------------------------------------------------
-- Crafting orders: discover pre-existing favorites from recipe list
----------------------------------------------------------------

local function DiscoverOrderFavorite(recipeID)
    if not recipeID or not orderCheckFav or not accountDB or not characterDB then return end
    if not orderCheckFav(recipeID) then return end
    local key = tostring(recipeID)
    if accountDB.orderFavorites[key] then return end
    accountDB.orderFavorites[key] = recipeID
    characterDB.orderSnapshot[key] = recipeID
end

local function ScanOrderResults()
    if not C_CraftingOrders or not C_CraftingOrders.GetCustomerOptions then return end
    local ok, results = pcall(C_CraftingOrders.GetCustomerOptions)
    if not ok or not results then return end
    for _, option in ipairs(results) do
        local recipeID = option.spellID or option.recipeID
        if recipeID then
            DiscoverOrderFavorite(recipeID)
        end
    end
end

----------------------------------------------------------------
-- Crafting orders: sync favorites between account DB and character
----------------------------------------------------------------

local function SyncOrderFavorites()
    if not accountDB or not characterDB or not orderHasAPI then return end
    orderSyncing = true

    if not characterDB.ordersInitialized then
        -- First session: push account favorites to character

        for key, recipeID in pairs(accountDB.orderFavorites) do
            orderSetFav(recipeID, true)
            characterDB.orderSnapshot[key] = recipeID
            Notify(true, GetRecipeLink(recipeID))
        end
        orderSyncing = false

        -- Discover this character's pre-existing favorites

        ScanOrderResults()
        return
    end

    -- Subsequent sessions: two-way diff

    for key, recipeID in pairs(accountDB.orderFavorites) do
        if not characterDB.orderSnapshot[key] then
            orderSetFav(recipeID, true)
            characterDB.orderSnapshot[key] = recipeID
            Notify(true, GetRecipeLink(recipeID))
        end
    end

    for key, recipeID in pairs(characterDB.orderSnapshot) do
        if not accountDB.orderFavorites[key] then
            orderSetFav(recipeID, false)
            characterDB.orderSnapshot[key] = nil
            Notify(false, GetRecipeLink(recipeID))
        end
    end

    orderSyncing = false
end

----------------------------------------------------------------
-- Event handling
----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)

    ----------------------------------------------------------------
    -- Addon loading
    ----------------------------------------------------------------

    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            MyTemsFavoritesDB = MyTemsFavoritesDB or {}
            accountDB = MyTemsFavoritesDB
            accountDB.favorites = accountDB.favorites or {}
            accountDB.orderFavorites = accountDB.orderFavorites or {}

            MyTemsFavoritesCharDB = MyTemsFavoritesCharDB or {}
            characterDB = MyTemsFavoritesCharDB
            characterDB.snapshot = characterDB.snapshot or {}
            characterDB.orderSnapshot = characterDB.orderSnapshot or {}

            -- Detect crafting order API early if already available

            if DetectCraftingOrderAPI() then
                HookCraftingOrderFavorites()
            end
        elseif addon == "Blizzard_ProfessionsCustomerOrders" then
            -- Crafting orders addon just loaded, detect API if not yet done

            if not orderHasAPI then
                if DetectCraftingOrderAPI() then
                    HookCraftingOrderFavorites()
                end
            end
            if ProfessionsCustomerOrdersFrame then
                ProfessionsCustomerOrdersFrame:HookScript("OnShow", function()
                    SyncOrderFavorites()
                end)
                ProfessionsCustomerOrdersFrame:HookScript("OnHide", function()
                    if characterDB and not characterDB.ordersInitialized then
                        characterDB.ordersInitialized = true
                    end
                end)
            end
        end
        return
    end

    ----------------------------------------------------------------
    -- Auction house events
    ----------------------------------------------------------------

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

    ----------------------------------------------------------------
    -- Crafting order events
    ----------------------------------------------------------------

    if event == "CRAFTINGORDERS_CUSTOMER_OPTIONS_PARSED" then
        ScanOrderResults()
        return
    end
end)
