# Marketeer Forever

Market, crafting, auction tracking, bag tools, and price trends for World of Warcraft: Forever. The in-game interface is branded **Marketeer**. The addon folder remains `NokiTrading` to preserve existing settings.

Install `NokiTrading` in the client's `Interface/AddOns` folder. The optional Windows data updater in `Updater/` retrieves AHledger market data and writes the separate `NokiTradingData` addon; enable it in the AddOns list and reload the UI after refreshing. Prices from AHledger (ahledger.com).

`Server/` contains the market trend collector, retention and export code. `Versions/` holds historical release packages, including older Noki Trading and beta releases in `Versions/Legacy/`. These are archives and can contain the old addon updater; use the current updater instead. The Marketeer 1.0.70 ZIP is the original CurseForge upload, retained unchanged; it does not represent later local changes.

The farming feature has been removed from the active addon. Its recovered code and data are preserved separately in the `archive/farming-1.0.81` Git branch.
