# Marketeer Forever data updater

The new `Marketeer Forever Data Updater.exe` downloads AHledger market data only. Install the compatible NokiTrading addon first, select its folder in the updater, choose the market and click Update now. The updater creates `Interface/AddOns/NokiTradingData` alongside it. Enable Marketeer Data in WoW's AddOns list for each character as needed. After an update, use `/reload` if WoW is running, or start the game. The updater does not update addon code; use CurseForge for that.

The current feed and addon target the WoW Forever client, not other game flavors. The data addon's interface version is copied from the selected NokiTrading TOC. The reader rejects companion data older than 48 hours; a failed download leaves the last generated data file in place. Existing manually imported market tables remain supported. Old versions of the updater still install addon code and write into the main folder: replace those separately when distributing this version.

## Manual verification

1. In a disposable Forever installation, install the updated NokiTrading folder without NokiTradingData and check that the addon loads and basic auction features work.
2. Run the new updater, select that NokiTrading folder and a market, then update. Check that NokiTradingData contains a TOC, MarketData.lua, and TrendData.lua, and that the NokiTrading folder was not changed.
3. Enable both addons, reload, and check AHledger sales/day and its displayed age for the selected market. Disable NokiTradingData and reload; confirm the addon still works without external sales data.
4. Refresh while WoW is open and use `/reload`; verify the new timestamp appears. Test a failed download and confirm MarketData.lua is unchanged. Replace the NokiTrading folder and confirm NokiTradingData remains.

## CurseForge

The public project name will be **Marketeer Forever**; the internal folder remains NokiTrading to preserve saved variables and compatibility. Release only files referenced by NokiTrading.toc under a single NokiTrading folder; exclude UpdaterData.lua, NokiTradingData, the updater, development data and executables. Review the package and changelog before each approved upload. The CurseForge project ID is 1803565; CurseForge requires the project ID and an author upload token. Store the token outside the repository, never in source control or chat. Publishing is a separate, explicitly approved action. Confirm CurseForge and Blizzard policies and supported game versions before any release; Forever compatibility and listing eligibility are not yet established.
