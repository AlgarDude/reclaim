-- reclaim by Algar
-- written in part using Sonnet 4.5
-- Version 1.0
-- A script to automatically reclaim alt currencies
-- /lua run reclaim will automatically start the process and exit when finished, broadcast this command as needed.

local mq = require('mq')

local invWindow = mq.TLO.Window('InventoryWindow')

-- Utility Functions
local function waitFor(conditionFunc, timeoutMs, checkIntervalMs)
    checkIntervalMs = checkIntervalMs or 100
    local elapsed = 0
    while elapsed < timeoutMs do
        if conditionFunc() then
            return true
        end
        mq.delay(checkIntervalMs)
        elapsed = elapsed + checkIntervalMs
    end
    return false
end

-- Window Management

local function openInventoryWindow()
    if invWindow() and invWindow.Open() then
        return true
    end

    invWindow.DoOpen()

    local success = waitFor(
        function()
            return invWindow() and invWindow.Open()
        end,
        5000
    )

    if not success then
        print("Reclaim: (ERROR) Failed to open inventory window.")
    end
    return success
end

local function closeInventoryWindow()
    if not invWindow() or not invWindow.Open() then
        return true
    end

    invWindow.DoClose()

    local success = waitFor(
        function()
            return not (invWindow() and invWindow.Open())
        end,
        5000
    )

    if not success then
        print("Reclaim: (WARNING) Failed to close inventory window.")
    end
    return success
end

-- Tab Navigation

local function getCurrentTabName(tabBox)
    return tabBox.CurrentTab and tabBox.CurrentTab.Name and tabBox.CurrentTab.Name() or "unknown"
end

local function switchToCurrencyTab()
    local tabBox = invWindow.Child('IW_Subwindows')
    if not tabBox or not tabBox() then
        print("Reclaim: (ERROR) Could not find inventory tab control.")
        return false
    end

    ---@diagnostic disable-next-line: undefined-field
    local tabCount = tabBox.TabCount() or 0

    -- Check tab 5 first (most common location for currency tab)
    tabBox.SetCurrentTab(5)
    mq.delay(250)

    if getCurrentTabName(tabBox) == "IW_AltCurrPage" then
        return true
    end

    -- If not at tab 5, search all tabs
    for i = 1, tabCount do
        if i ~= 5 then
            tabBox.SetCurrentTab(i)
            mq.delay(250)

            if getCurrentTabName(tabBox) == "IW_AltCurrPage" then
                return true
            end
        end
    end

    print("Reclaim: (ERROR) Could not find alt currency tab.")
    return false
end

-- Show All Currencies Option

local function ensureShowAllEnabled()
    local button = invWindow.Child('IW_AltCurr_DisplayMissingButton')

    if not button or not button() then
        print("Reclaim: (ERROR) 'Show all' button not found.")
        return false
    end

    if button.Checked and button.Checked() then
        return true
    end

    button.LeftMouseUp()
    mq.delay(100, function() return button.Checked() end)
    return true
end

-- Currency Reclaim

local function reclaimAllCurrencies()
    local currencyList = invWindow.Child('IW_AltCurr_PointList')

    if not currencyList or not currencyList() then
        print("Reclaim: (ERROR) Currency list not found.")
        return 0
    end

    local itemCount = currencyList.Items() or 0
    if itemCount == 0 then
        return 0
    end

    local reclaimBtn = invWindow.Child('IW_AltCurr_ReclaimButton')
    if not reclaimBtn or not reclaimBtn() then
        print("Reclaim: (ERROR) Reclaim button not found.")
        return 0
    end

    local tabBox = invWindow.Child('IW_Subwindows')
    local reclaimedCount = 0

    for i = 1, itemCount do
        -- Safety checks
        if not invWindow.Open() then
            print("Reclaim: (ERROR) Inventory window closed during reclaim.")
            return reclaimedCount
        end

        if tabBox and tabBox() and getCurrentTabName(tabBox) ~= "IW_AltCurrPage" then
            print("Reclaim: (ERROR) Currency tab is no longer active.")
            return reclaimedCount
        end

        currencyList.Select(i)
        ---@diagnostic disable-next-line: undefined-field
        mq.delay(100, function() return currencyList.SelectedIndex() == i end)

        reclaimBtn.LeftMouseUp()
        reclaimedCount = reclaimedCount + 1

        mq.delay(50)
    end

    return reclaimedCount
end

-- Main Execution

local function main()
    print("Reclaim: Alt-Currency Reclaim Initiated")

    if not openInventoryWindow() then
        return
    end

    if not switchToCurrencyTab() then
        closeInventoryWindow()
        return
    end

    if not ensureShowAllEnabled() then
        closeInventoryWindow()
        return
    end

    mq.delay(200) -- Allow list to repopulate after show all

    local count = reclaimAllCurrencies()

    closeInventoryWindow()

    printf("Reclaim: All done! Processed %d currencies.", count)
end

-- Entry Point

main()
