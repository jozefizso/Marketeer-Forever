# Marketeer Forever data updater

The `Marketeer Forever Data Updater.exe` downloads AHledger market, trend and history data only. Install the compatible `MarketeerForever` addon first, select its folder in the updater, choose the market and click Update now. The updater creates `Interface/AddOns/MarketeerForeverData` alongside it. Enable Marketeer Data in WoW's AddOns list for each character as needed. After an update, use `/reload` if WoW is running, or start the game. The updater does not update addon code; use CurseForge for that.

The current feed and addon target the WoW Forever client, not other game flavors. The data addon's interface version is copied from the selected NokiTrading TOC. The reader rejects companion data older than 48 hours; a failed download leaves the last generated data file in place. Existing manually imported market tables remain supported. Old versions of the updater still install addon code and write into the main folder: replace those separately when distributing this version.

## Manual verification

1. In a disposable Forever installation, install the updated `MarketeerForever` folder without `MarketeerForeverData` and check that the addon loads and basic auction features work.
2. Run the updater, select that folder and a market, then update. Check that `MarketeerForeverData` contains its TOC, MarketData.lua, TrendData.lua, HistoryData.lua, and ItemNames.lua, and that the main addon folder was not changed.
3. Enable both addons, reload, and check AHledger sales/day and its displayed age for the selected market. Disable the data addon and reload; confirm the addon still works without external sales data.
4. Refresh while WoW is open and use `/reload`; verify the new timestamp appears. Test a failed download and confirm MarketData.lua is unchanged. Replace the main addon folder and confirm the data addon remains.

## CurseForge

The public project name is **Marketeer Forever**. Release only files referenced by `MarketeerForever.toc` under a single `MarketeerForever` folder, together with required attribution files; exclude generated market data, `MarketeerForeverData`, the updater, development data and executables. Review the package and changelog before each approved upload. The CurseForge project ID is 1803565; CurseForge requires an author upload token. Store the token outside the repository, never in source control or chat. Publishing is a separate, explicitly approved action.
