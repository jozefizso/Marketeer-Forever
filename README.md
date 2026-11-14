# Marketeer Forever

Market, crafting, auction tracking, bag tools, and price trends for World of Warcraft: Forever. The in-game interface is branded **Marketeer** and the addon folder is `MarketeerForever`.

Install `MarketeerForever` using [CurseForge](https://www.curseforge.com/wow/addons/marketeer-forever) or place the addon folder in the client's `Interface/AddOns` folder. For market data, download the [Windows Marketeer Forever Data Updater](https://github.com/PyNoki/Marketeer-Forever/releases/latest/download/Marketeer-Forever-Data-Updater.exe), run it, select your addon folder and market, and choose **Update now**. It creates the separate `MarketeerForeverData` addon; enable it in the AddOns list and use `/reload` after refreshing. The updater only refreshes data; CurseForge updates the main addon. Prices from [AHledger](https://ahledger.com/).

Open `/marketeer` and select **Market history** to search by item name, item ID, or item link. Partial-name searches show selectable results. Alt+left-click a Market Vision item row to open its history; supported item links also have an additive Alt+left-click hook. The graph shows every retained hourly low buyout, up to 14 days; gaps indicate missing observations. The updater supplies an item-name catalog, with the game's item cache as another source. Drag the window's **Resize** handle to change its width and height; the size is saved.

If upgrading from `NokiTrading`, close WoW before first launching the renamed addon and run `Tools/Migrate-LegacySettings.ps1` in PowerShell, using `-GamePath` if your Forever client is not in the default location. The tool copies each account's old saved variables without overwriting any existing Marketeer save. The addon imports the copied settings on first load. Keep the old save files as backups, but remove or disable the old `NokiTrading` and `NokiTradingData` addons to avoid duplicate functionality. Saved variables cannot be migrated by an addon after its folder name changes without this separate one-time step.

`Server/` contains the market trend collector, retention and export code. `Versions/` holds release packages, including older Noki Trading and beta releases in `Versions/Legacy/`. The legacy archives can contain the old addon updater; use the current updater instead. The Marketeer 1.0.70 ZIP is the original CurseForge upload.

The farming feature has been removed from the active addon. Its recovered code and data are preserved separately in the `archive/farming-1.0.81` Git branch.
