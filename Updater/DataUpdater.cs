using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace MarketeerForever.Updater;

sealed class Market
{
    public Market(string region, string ruleset, string faction)
    {
        Region = region;
        Ruleset = ruleset;
        Faction = faction;
    }

    public string Region { get; }
    public string Ruleset { get; }
    public string Faction { get; }
    public string Key => Ruleset + "_" + Faction + "_" + Region;
    public string Id => "forever/" + Ruleset + "/" + Faction + "/" + Region;
}

static class DataUpdater
{
    const string BaseUrl = "https://devvy.xyz/marketeer/";
    const string AddonToc = "MarketeerForever.toc";
    const string DataAddonName = "MarketeerForeverData";
    const long MaxPrice = 2000000000000L;

    static readonly UTF8Encoding Utf8NoBom = new UTF8Encoding(false);

    public static string CacheDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MarketeerForeverUpdater");

    public static string Update(Market market, string addonFolder)
    {
        int count = FetchMarketData(market, addonFolder);
        string result = "Updated " + count + " items.";
        result += TryOptional("Trends", () => FetchTrends(market, addonFolder));
        result += TryOptional("History", () => FetchHistory(market, addonFolder));
        result += TryOptional("Names", () => FetchNames(addonFolder));
        return result;
    }

    static string TryOptional(string label, Func<int> fetch)
    {
        try
        {
            return " " + label + ": " + fetch() + ".";
        }
        catch (Exception e)
        {
            return " " + label + " unavailable: " + e.Message + "; previous kept.";
        }
    }

    static string DataDirectory(string addonFolder)
    {
        return Path.Combine(
            Directory.GetParent(Path.GetFullPath(addonFolder)).FullName,
            DataAddonName);
    }

    static string Download(string url, string userAgent = "MarketeerForeverDataUpdater/1.0")
    {
        using var client = new WebClient();
        client.Headers.Add(HttpRequestHeader.UserAgent, userAgent);
        return client.DownloadString(url);
    }

    static void WriteAtomically(string target, string content, string validationError)
    {
        string tmp = target + ".tmp";
        try
        {
            File.WriteAllText(tmp, content, Utf8NoBom);
            if (File.ReadAllText(tmp) != content)
            {
                throw new Exception(validationError);
            }

            if (File.Exists(target))
            {
                File.Replace(tmp, target, null);
            }
            else
            {
                File.Move(tmp, target);
            }
        }
        finally
        {
            if (File.Exists(tmp))
            {
                File.Delete(tmp);
            }
        }
    }

    static void WritePlaceholder(string path, string content)
    {
        if (!File.Exists(path))
        {
            File.WriteAllText(path, content, Utf8NoBom);
        }
    }

    static bool IsValidTimestamp(string text, out long value)
    {
        return long.TryParse(text, out value)
            && value > 0
            && value <= DateTimeOffset.UtcNow.ToUnixTimeSeconds() + 300;
    }

    static bool IsValidCount(string text, out int value, int min = 0)
    {
        return int.TryParse(text, out value) && value >= min && value <= 100000;
    }

    static string[] SplitLines(string text)
    {
        return text.Replace("\r", "").TrimEnd('\n').Split('\n');
    }

    static int FetchMarketData(Market market, string addonFolder)
    {
        string tocPath = Path.Combine(addonFolder, AddonToc);
        if (!File.Exists(tocPath))
        {
            throw new Exception("Select the Marketeer addon folder");
        }

        string toc = File.ReadAllText(tocPath);
        if (!toc.Contains(DataAddonName))
        {
            throw new Exception("Install a compatible Marketeer addon first");
        }

        DirectoryInfo addons = Directory.GetParent(Path.GetFullPath(addonFolder));
        if (addons == null || !addons.Name.Equals("AddOns", StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception("Select the Marketeer folder inside Interface/AddOns");
        }

        Match interfaceVersion = Regex.Match(toc, @"(?m)^##\s*Interface:\s*(\d+)");
        if (!interfaceVersion.Success)
        {
            throw new Exception("Cannot determine interface version");
        }

        string dataDir = Path.Combine(addons.FullName, DataAddonName);
        string url = BaseUrl + "market-data.php?region=" + market.Region
            + "&ruleset=" + market.Ruleset + "&faction=" + market.Faction;
        string text = Download(url, "MarketeerForeverUpdater/1.0");
        ValidateMarketTable(text, market.Id);

        Directory.CreateDirectory(CacheDirectory);
        File.WriteAllText(Path.Combine(CacheDirectory, market.Key + ".txt"), text, Utf8NoBom);

        var result = new StringBuilder("-- AHledger data generated by Marketeer Data Updater.\n_G.MarketeerForeverMarketData = {schemaVersion=1,periodHours=24,generatedAt=")
            .Append(DateTimeOffset.UtcNow.ToUnixTimeSeconds())
            .Append(",tables={\n");
        int count = 0;
        foreach (string file in Directory.GetFiles(CacheDirectory, "*.txt"))
        {
            string name = Path.GetFileNameWithoutExtension(file);
            if (!Regex.IsMatch(name, @"^(normal|pvp|rp|rppvp)_(alliance|horde)_(us|eu|cn)$"))
            {
                continue;
            }

            string[] parts = name.Split('_');
            string cachedMarket = "forever/" + parts[0] + "/" + parts[1] + "/" + parts[2];
            MarketTable table = ValidateMarketTable(File.ReadAllText(file), cachedMarket);
            if (cachedMarket == market.Id)
            {
                count = table.Count;
            }

            result.Append("[\"").Append(cachedMarket)
                .Append("\"]={updated=").Append(table.Updated)
                .Append(",count=").Append(table.Count)
                .Append(",text=[==[\n").Append(table.Body).Append("\n]==]},\n");
        }

        result.Append("}}\n");
        Directory.CreateDirectory(dataDir);
        WriteAtomically(Path.Combine(dataDir, "MarketData.lua"), result.ToString(), "Data validation failed");

        WritePlaceholder(Path.Combine(dataDir, "TrendData.lua"), "-- Trend data not yet available.\n");
        WritePlaceholder(Path.Combine(dataDir, "HistoryData.lua"), "-- Price history not yet available.\n");
        WritePlaceholder(Path.Combine(dataDir, "ItemNames.lua"), "-- Item names not yet available.\n");

        string dataToc = "## Interface: " + interfaceVersion.Groups[1].Value + "\n"
            + "## Title: Marketeer Data\n"
            + "## IconTexture: Interface\\MoneyFrame\\UI-GoldIcon\n"
            + "## Notes: AHledger data\n"
            + "MarketData.lua\n"
            + "TrendData.lua\n"
            + "HistoryData.lua\n"
            + "ItemNames.lua\n";
        WriteAtomically(Path.Combine(dataDir, DataAddonName + ".toc"), dataToc, "TOC validation failed");
        return count;
    }

    static long Base36(string input)
    {
        if (string.IsNullOrEmpty(input) || input.Length > 12)
        {
            throw new Exception("Invalid history number");
        }

        long n = 0;
        foreach (char c in input)
        {
            int digit = c >= '0' && c <= '9' ? c - '0'
                : c >= 'a' && c <= 'z' ? c - 'a' + 10
                : -1;
            if (digit < 0 || n > (long.MaxValue - digit) / 36)
            {
                throw new Exception("Invalid history number");
            }

            n = n * 36 + digit;
        }

        return n;
    }

    static int FetchHistory(Market market, string addonFolder)
    {
        string text = Download(BaseUrl + "history-export-v2.php?market=" + Uri.EscapeDataString(market.Id));
        if (text.Length > 32000000)
        {
            throw new Exception("History data is too large");
        }

        string[] lines = SplitLines(text);
        string[] header = lines[0].Split('|');
        if (header.Length != 4
            || header[0] != "HST2"
            || header[1] != market.Id
            || !IsValidTimestamp(header[2], out long generated)
            || !IsValidCount(header[3], out int count)
            || lines.Length != count + 1)
        {
            throw new Exception("Invalid history header");
        }

        var result = new StringBuilder("-- AHledger hourly low buyouts.\n_G.MarketeerForeverHistory={schemaVersion=2,market=\"")
            .Append(market.Id)
            .Append("\",generatedAt=").Append(generated)
            .Append(",items={\n");
        var seen = new HashSet<int>();
        for (int i = 1; i < lines.Length; i++)
        {
            int colon = lines[i].IndexOf(':');
            if (colon <= 0 || !int.TryParse(lines[i].Substring(0, colon), out int id) || id <= 0 || !seen.Add(id))
            {
                throw new Exception("Invalid history item");
            }

            string points = lines[i].Substring(colon + 1);
            string[] entries = points.Split(';');
            if (entries.Length < 1 || entries.Length > 400)
            {
                throw new Exception("Invalid history count");
            }

            int previous = 337;
            foreach (string entry in entries)
            {
                string[] fields = entry.Split(',');
                if (fields.Length != 2)
                {
                    throw new Exception("Invalid history point");
                }

                long age = Base36(fields[0]);
                long price = Base36(fields[1]);
                if (age > 336 || age >= previous || price <= 0 || price > MaxPrice)
                {
                    throw new Exception("Invalid history point");
                }

                previous = (int)age;
            }

            result.Append('[').Append(id).Append("] = \"").Append(points).Append("\",\n");
        }

        result.Append("}}\n");
        WriteAtomically(
            Path.Combine(DataDirectory(addonFolder), "HistoryData.lua"),
            result.ToString(),
            "History validation failed");
        return count;
    }

    static int FetchNames(string addonFolder)
    {
        string text = Download(BaseUrl + "names-export.php");
        if (text.Length > 5000000)
        {
            throw new Exception("Name catalog too large");
        }

        string[] lines = SplitLines(text);
        string[] header = lines[0].Split('|');
        if (header.Length != 3
            || header[0] != "NAM1"
            || !IsValidTimestamp(header[1], out _)
            || !IsValidCount(header[2], out int count)
            || lines.Length != count + 1)
        {
            throw new Exception("Invalid name catalog header");
        }

        var result = new StringBuilder("-- Item names for market history search.\n_G.MarketeerForeverItemNames={schemaVersion=1,items={\n");
        var seen = new HashSet<int>();
        var strictUtf8 = new UTF8Encoding(false, true);
        for (int i = 1; i < lines.Length; i++)
        {
            int colon = lines[i].IndexOf(':');
            if (colon <= 0 || !int.TryParse(lines[i].Substring(0, colon), out int id) || id <= 0 || !seen.Add(id))
            {
                throw new Exception("Invalid name item");
            }

            byte[] bytes;
            try
            {
                bytes = Convert.FromBase64String(lines[i].Substring(colon + 1));
            }
            catch
            {
                throw new Exception("Invalid encoded item name");
            }

            string name = strictUtf8.GetString(bytes);
            if (name.Length < 1 || name.Length > 160 || bytes.Length > 640)
            {
                throw new Exception("Invalid item name");
            }

            result.Append('[').Append(id).Append("] = \"");
            foreach (byte b in bytes)
            {
                result.Append('\\').Append(b.ToString("D3"));
            }

            result.Append("\",\n");
        }

        result.Append("}}\n");
        WriteAtomically(
            Path.Combine(DataDirectory(addonFolder), "ItemNames.lua"),
            result.ToString(),
            "Name validation failed");
        return count;
    }

    static int FetchTrends(Market market, string addonFolder)
    {
        string text = Download(BaseUrl + "trends-export-v2.php?market=" + Uri.EscapeDataString(market.Id));
        if (text.Length > 4000000)
        {
            throw new Exception("Trend data is too large");
        }

        string[] lines = SplitLines(text);
        string[] header = lines[0].Split('|');
        if (header.Length != 4
            || header[0] != "TRD2"
            || header[1] != market.Id
            || !IsValidTimestamp(header[2], out long generated)
            || !IsValidCount(header[3], out int count)
            || lines.Length != count + 1)
        {
            throw new Exception("Invalid trend header");
        }

        var result = new StringBuilder("-- AHledger low-price trend summaries.\n_G.MarketeerForeverTrends={schemaVersion=2,market=\"")
            .Append(market.Id)
            .Append("\",generatedAt=").Append(generated)
            .Append(",items={\n");
        var seen = new HashSet<string>();
        for (int i = 1; i < lines.Length; i++)
        {
            if (!Regex.IsMatch(lines[i], @"^[1-9]\d*:\d*:\d*:\d*:\d*:\d+$"))
            {
                throw new Exception("Invalid trend row");
            }

            string[] p = lines[i].Split(':');
            if (!long.TryParse(p[0], out long item)
                || item > int.MaxValue
                || !seen.Add(p[0])
                || !long.TryParse(p[5], out long last)
                || last <= 0
                || last > generated + 300)
            {
                throw new Exception("Invalid trend item");
            }

            for (int j = 1; j <= 4; j++)
            {
                if (p[j].Length > 0 && (!long.TryParse(p[j], out long value) || value <= 0 || value > MaxPrice))
                {
                    throw new Exception("Invalid trend price");
                }
            }

            result.Append('[').Append(p[0]).Append("]={");
            for (int j = 1; j <= 4; j++)
            {
                result.Append(p[j].Length == 0 ? "false" : p[j]).Append(',');
            }

            result.Append(p[5]).Append("},\n");
        }

        result.Append("}}\n");
        WriteAtomically(
            Path.Combine(DataDirectory(addonFolder), "TrendData.lua"),
            result.ToString(),
            "Trend data validation failed");
        return count;
    }

    sealed class MarketTable
    {
        public string Updated { get; set; }
        public int Count { get; set; }
        public string Body { get; set; }
    }

    static MarketTable ValidateMarketTable(string text, string marketPath)
    {
        if (text.Length > 2000000)
        {
            throw new Exception("Data is too large");
        }

        text = text.Replace("\r", "");
        int newline = text.IndexOf('\n');
        if (newline < 0)
        {
            throw new Exception("Invalid AHledger table");
        }

        string[] header = text.Substring(0, newline).Split('|');
        if (header.Length != 4
            || header[0] != "AHL1"
            || header[1] != marketPath
            || !IsValidTimestamp(header[2], out _)
            || !IsValidCount(header[3], out int count, min: 1))
        {
            throw new Exception("Invalid market or table header");
        }

        string body = text.Substring(newline + 1).Trim();
        string[] rows = body.Split('\n');
        if (rows.Length != count)
        {
            throw new Exception("Incomplete market table");
        }

        foreach (string row in rows)
        {
            if (!Regex.IsMatch(row, @"^\d+(?::\d*){8}$"))
            {
                throw new Exception("Invalid market row");
            }
        }

        return new MarketTable { Updated = header[2], Count = count, Body = body };
    }
}
