-- [collect all loot items instantly when the loot window opens]

local LOOT_DELAY = 0.1
local lastLootTime = 0

local LootFrame = CreateFrame("Frame")
LootFrame:RegisterEvent("LOOT_READY")
LootFrame:SetScript("OnEvent", function()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        return
    end
    if (GetTime() - lastLootTime) < LOOT_DELAY then
        return
    end
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
    end
    lastLootTime = GetTime()
end)