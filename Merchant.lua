-- Auto sell junk and repair gear when visiting a merchant

local vendorFrm = CreateFrame("Frame")
vendorFrm:RegisterEvent("MERCHANT_SHOW")
vendorFrm:SetScript("OnEvent", function()
    C_Timer.After(0.1, function()
        if MerchantSellAllJunkButton and MerchantSellAllJunkButton:IsShown() then
            MerchantSellAllJunkButton:Click()
        end
        if MerchantRepairAllButton and MerchantRepairAllButton:IsShown() then
            MerchantRepairAllButton:Click()
        end
    end)
    C_Timer.After(0.1, function()
        if StaticPopup1Button1 and StaticPopup1Button1:IsShown() then
            StaticPopup1Button1:Click()
        end
    end)
end)
