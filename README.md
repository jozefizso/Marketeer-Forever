# Marketeer Forever

Market, crafting, auction tracking, bag tools, and price trends for World of Warcraft: Forever. The in-game interface is branded **Marketeer** and the addon folder is `MarketeerForever`.

Install `MarketeerForever` in the client's `Interface/AddOns` folder. The optional Windows data updater in `Updater/` retrieves AHledger market data and writes the separate `MarketeerForeverData` addon; enable it in the AddOns list and reload the UI after refreshing. Prices from AHledger (ahledger.com).

Open `/marketeer` and select **Market history** to search by item name, item ID, or item link. Alt+left-click a Market Vision item row to open its history; supported item links also have an additive Alt+left-click hook. The graph shows available hourly low buyouts for the latest 48 hours and daily median lows for older observations, up to 14 days. Gaps indicate missing observations. Name searches require the item's name to be cached by the game; use an ID or link if it is not found.

If upgrading from `NokiTrading`, close WoW before first launching the renamed addon and run `Tools/Migrate-LegacySettings.ps1` in PowerShell, using `-GamePath` if your Forever client is not in the default location. The tool copies each account's old saved variables without overwriting any existing Marketeer save. The addon imports the copied settings on first load. Keep the old save files as backups, but remove or disable the old `NokiTrading` and `NokiTradingData` addons to avoid duplicate functionality. Saved variables cannot be migrated by an addon after its folder name changes without this separate one-time step.

`Server/` contains the market trend collector, retention and export code. `Versions/` holds historical release packages, including older Noki Trading and beta releases in `Versions/Legacy/`. These are archives and can contain the old addon updater; use the current updater instead. The Marketeer 1.0.70 ZIP is the original CurseForge upload, retained unchanged; it does not represent later local changes.

The farming feature has been removed from the active addon. Its recovered code and data are preserved separately in the `archive/farming-1.0.81` Git branch.
