# Marketeer auction sync beta

This is a separate experimental addon for testing whether WoW: Forever permits shared custom-channel addon messages. It requires the main Marketeer addon. **Server-wide delivery is not established**, and this test may fail if the game blocks addon messages in custom channels. It never falls back to ordinary visible chat messages.

Install `MarketeerForeverSyncBeta` alongside `MarketeerForever` in `Interface/AddOns`, then reload. At least two people in the same region, ruleset and faction must install and enable it. Both need to be online and in the same game channel. The test joins the temporary `MarketeerBetaSync` channel, which can be left by disabling the beta and leaving that channel.

At an auction house, open Market Vision and click the green **Scan & Sync** button. It runs a normal local scan and sends a small peer probe. If a peer replies within 15 seconds, up to 3,000 item prices from that completed scan are sent in throttled packets. Shared prices appear separately in item tooltips for up to one hour; they do not overwrite your own scan, AHledger data, selling rules, or price history. Do not rely on experimental, unverified prices to make trading decisions.

If there is no peer response, no prices are sent and the addon reports that communication was not confirmed. A successful API call alone is not proof of server-wide delivery. Peers may be unable to communicate due to client, channel, faction, region, account, or other restrictions. The beta does not transmit personal messages or use normal public chat as a workaround.
