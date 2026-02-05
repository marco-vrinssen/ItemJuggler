local TIMER = 0
local DELAY = 0.1

local function Loot()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        if (GetTime() - TIMER) >= DELAY then
            if TSMDestroyBtn and TSMDestroyBtn:IsShown() and TSMDestroyBtn:GetButtonState() == "DISABLED" then
                TIMER = GetTime()
                return
            end
            for i = GetNumLootItems(), 1, -1 do
                LootSlot(i)
            end
            TIMER = GetTime()
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_READY")
f:SetScript("OnEvent", Loot)
