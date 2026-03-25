-- Instantly loot all items without showing the loot frame

-- Hide the loot frame by reparenting it to an invisible container
local lootFrameHiddenContainer = CreateFrame("Frame")
lootFrameHiddenContainer:Hide()

LootFrame:SetParent(lootFrameHiddenContainer)

-- Suppress the loot frame from appearing while hidden
local originalLootFrameShow = LootFrame.Show

LootFrame.Show = function(self, ...)
    if self:GetParent() == lootFrameHiddenContainer then
        return
    end
    return originalLootFrameShow(self, ...)
end

-- Determine whether auto-loot is currently active based on CVar and modifier key
local function IsAutoLootActive()
    return GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
end

-- Collect all loot slots in reverse order to avoid index shifting
local function CollectAllLootSlots()
    for slotIndex = GetNumLootItems(), 1, -1 do
        LootSlot(slotIndex)
    end
end

-- Handle loot events to either instantly collect or show the default loot frame
local instantLootHandler = CreateFrame("Frame")

instantLootHandler:RegisterEvent("LOOT_READY")
instantLootHandler:RegisterEvent("LOOT_CLOSED")

instantLootHandler:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" then
        if IsAutoLootActive() then
            CollectAllLootSlots()
        else
            LootFrame:SetParent(UIParent)
        end

    elseif event == "LOOT_CLOSED" then
        LootFrame:SetParent(lootFrameHiddenContainer)
    end
end)
