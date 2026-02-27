-- Auto loot all items and close empty loot frames

local lootFrm = CreateFrame("Frame")
local lastLootTime = 0
local LOOT_DELAY = 0.1

local function CloseLootIfEmpty()
    if GetNumLootItems() == 0 then
        CloseLoot()
        if LootFrame then LootFrame:Hide() end
        if LootFrameBG then LootFrameBG:Hide() end
    end
end

lootFrm:RegisterEvent("LOOT_READY")
lootFrm:SetScript("OnEvent", function()
    if GetCVarBool("autoLootDefault") == IsModifiedClick("AUTOLOOTTOGGLE") then
        return
    end
    if (GetTime() - lastLootTime) < LOOT_DELAY then
        return
    end
    if GetNumLootItems() == 0 then
        CloseLootIfEmpty()
        return
    end
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
    end
    lastLootTime = GetTime()
    C_Timer.After(0.2, CloseLootIfEmpty)
end)