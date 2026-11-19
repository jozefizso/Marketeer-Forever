using System;
using System.IO;

namespace MarketeerForever.Updater;

sealed class SettingsData
{
    public int? Region { get; set; }
    public int? Ruleset { get; set; }
    public int? Faction { get; set; }
    public string Folder { get; set; } = "";
    public bool? AutoUpdate { get; set; }
}

sealed class Settings
{
    readonly string cacheDirectory;

    public Settings(string cacheDirectory)
    {
        this.cacheDirectory = cacheDirectory;
    }

    public static string DefaultAddonFolder => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
        @"World of Warcraft\_forever_\Interface\AddOns\MarketeerForever");

    string FilePath => Path.Combine(cacheDirectory, "settings.txt");

    static string LegacyFilePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NokiTradingUpdater",
        "settings.txt");

    public void Save(SettingsData data)
    {
        try
        {
            Directory.CreateDirectory(cacheDirectory);
            File.WriteAllLines(FilePath, new[]
            {
                data.Region.ToString(),
                data.Ruleset.ToString(),
                data.Faction.ToString(),
                data.Folder,
                data.AutoUpdate.ToString(),
            });
        }
        catch
        {
            // Settings are a convenience; failing to save them must not block updates.
        }
    }

    public SettingsData Load()
    {
        try
        {
            string path = File.Exists(FilePath) ? FilePath : LegacyFilePath;
            if (!File.Exists(path))
            {
                return null;
            }

            string[] lines = File.ReadAllLines(path);
            if (lines.Length < 5)
            {
                return null;
            }

            return new SettingsData
            {
                Region = ParseInt(lines[0]),
                Ruleset = ParseInt(lines[1]),
                Faction = ParseInt(lines[2]),
                Folder = MigrateLegacyFolder(lines[3]),
                AutoUpdate = bool.TryParse(lines[4], out bool auto) ? auto : null,
            };
        }
        catch
        {
            return null;
        }
    }

    static int? ParseInt(string text)
    {
        return int.TryParse(text, out int value) ? value : null;
    }

    static string MigrateLegacyFolder(string folder)
    {
        if (folder.Length == 0)
        {
            return folder;
        }

        string trimmed = folder.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (Path.GetFileName(trimmed).Equals("NokiTrading", StringComparison.OrdinalIgnoreCase))
        {
            return Path.Combine(Directory.GetParent(trimmed).FullName, "MarketeerForever");
        }

        return folder;
    }
}
