-- Auto-loot engine with loot frame visibility management
-- Based on SpeedyAutoLoot by Veritass

local LOOT_SLOT_ITEM    = Enum.LootSlotType.Item
local LOOT_SLOT_NONE    = Enum.LootSlotType.None
local REAGENT_BAG_INDEX = 5
local TICK_INTERVAL     = 0.033

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetToplevel(true)
hiddenParent:Hide()

local looting           = false
local lootFrameHidden   = true
local anySlotLocked     = false
local previousItemCount = nil
local autoLootActive    = false
local anySlotFailed     = false
local lootTicker        = nil

----------------------------------------------------------------
-- Bag space
----------------------------------------------------------------

local function CanFitInBags(itemLink, quantity)
    local stackSize, _, _, _, _, _, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(itemLink))
    local itemFamily = C_Item.GetItemFamily(itemLink)

    -- Check existing partial stacks
    local owned = C_Item.GetItemCount(itemLink)
    if owned > 0 and stackSize > 1 then
        if ((stackSize - owned) % stackSize) >= quantity then
            return true
        end
    end

    -- Check each bag for a free slot that accepts this item
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if freeSlots > 0 then
            if bag == REAGENT_BAG_INDEX then
                return isCraftingReagent and true or false
            end
            if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
                return true
            end
        end
    end

    return false
end

----------------------------------------------------------------
-- Loot frame positioning
----------------------------------------------------------------

local function PositionLootFrame()
    local lf = LootFrame
    if GetCVarBool("lootUnderMouse") then
        local cursorX, cursorY = GetCursorPosition()
        lf:ClearAllPoints()
        local scale = lf:GetEffectiveScale()
        local x = cursorX / scale - 30
        local y = math.max(cursorY / scale + 50, 350)
        lf:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
        lf:Raise()
    else
        local anchor = lf.systemInfo.anchorInfo
        local scale  = lf:GetScale()
        lf:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint,
            anchor.offsetX / scale, anchor.offsetY / scale)
    end
end

local function RevealLootFrame(isDelayed)
    lootFrameHidden = false
    if not LootFrame:IsEventRegistered("LOOT_OPENED") then return end

    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
    PositionLootFrame()
    if isDelayed then
        PositionLootFrame()
    end
end

local function HideLootFrame()
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(hiddenParent)
    end
end

----------------------------------------------------------------
-- Per-slot looting
----------------------------------------------------------------

local function CancelTicker()
    if lootTicker then
        lootTicker:Cancel()
    end
end

local function TryLootSlot(slotIndex)
    local slotType = GetLootSlotType(slotIndex)
    if slotType == LOOT_SLOT_NONE then
        return true
    end

    local itemLink    = GetLootSlotLink(slotIndex)
    local quantity, _, _, isLocked, isQuestItem = select(3, GetLootSlotInfo(slotIndex))

    if isLocked then
        anySlotLocked = true
        return false
    end

    if slotType ~= LOOT_SLOT_ITEM or isQuestItem or CanFitInBags(itemLink, quantity) then
        LootSlot(slotIndex)
        return true
    end

    return false
end

local function LootAllSlots(totalSlots)
    CancelTicker()
    local nextSlot = totalSlots

    lootTicker = C_Timer.NewTicker(TICK_INTERVAL, function()
        if nextSlot >= 1 then
            if not TryLootSlot(nextSlot) then
                anySlotFailed = true
            end
            nextSlot = nextSlot - 1
        else
            if anySlotFailed then
                RevealLootFrame()
            end
            CancelTicker()
        end
    end, totalSlots + 1)
end

----------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------

local function OnLootReady(isAutoLoot)
    looting = true

    if not autoLootActive then
        autoLootActive = isAutoLoot
            or (not isAutoLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE"))
    end

    local itemCount = GetNumLootItems()
    if itemCount == 0 or previousItemCount == itemCount then
        return
    end

    if autoLootActive then
        LootAllSlots(itemCount)
    else
        RevealLootFrame()
    end

    previousItemCount = itemCount
end

local function OnLootClosed()
    looting           = false
    lootFrameHidden   = true
    anySlotLocked     = false
    previousItemCount = nil
    autoLootActive    = false
    anySlotFailed     = false
    CancelTicker()
    HideLootFrame()
end

local function OnBagError(_, message)
    if not (looting and lootFrameHidden) then return end
    if message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT or message == ERR_LOOT_ROLL_PENDING then
        RevealLootFrame(true)
    end
end

----------------------------------------------------------------
-- Event registration
----------------------------------------------------------------

hiddenParent:RegisterEvent("LOOT_READY")
hiddenParent:RegisterEvent("LOOT_OPENED")
hiddenParent:RegisterEvent("LOOT_CLOSED")
hiddenParent:RegisterEvent("UI_ERROR_MESSAGE")

hiddenParent:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        OnLootReady(...)
    elseif event == "LOOT_CLOSED" then
        OnLootClosed()
    elseif event == "UI_ERROR_MESSAGE" then
        OnBagError(...)
    end
end)

-- Keep loot frame parented correctly during EditMode
if LootFrame:IsEventRegistered("LOOT_OPENED") then
    hooksecurefunc(LootFrame, "UpdateShownState", function(self)
        if self.isInEditMode then
            self:SetParent(UIParent)
        else
            self:SetParent(hiddenParent)
        end
    end)
end

-- Delay initial hide so other addons finish hooking LootFrame
C_Timer.After(6, HideLootFrame)