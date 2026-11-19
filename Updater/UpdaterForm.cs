using System;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace MarketeerForever.Updater;

sealed class UpdaterForm : Form
{
    static readonly string[] Regions = { "US", "EU", "CN" };
    static readonly string[] Rulesets = { "Normal", "PvP", "RP", "RP PvP" };
    static readonly string[] Factions = { "Alliance", "Horde" };

    readonly ComboBox region = new ComboBox();
    readonly ComboBox ruleset = new ComboBox();
    readonly ComboBox faction = new ComboBox();
    readonly TextBox folder = new TextBox();
    readonly Label status = new Label();
    readonly Button update = new Button();
    readonly CheckBox auto = new CheckBox();
    readonly Timer timer = new Timer();
    readonly Settings settings = new Settings(DataUpdater.CacheDirectory);
    bool loading = true;

    public UpdaterForm()
    {
        Text = "Marketeer Data Updater";
        ClientSize = new Size(590, 320);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;

        Controls.Add(new Label
        {
            Text = "AHledger market data for Marketeer",
            Left = 20,
            Top = 15,
            Width = 540,
            Height = 24,
            Font = new Font(Font, FontStyle.Bold),
        });

        AddLabel("Region", 20, 53);
        AddLabel("Ruleset", 175, 53);
        AddLabel("Faction", 365, 53);
        SetupComboBox(region, 20, 75, 140, Regions);
        SetupComboBox(ruleset, 175, 75, 175, Rulesets);
        SetupComboBox(faction, 365, 75, 200, Factions);

        AddLabel("Marketeer addon folder", 20, 118);
        folder.SetBounds(20, 141, 445, 25);
        folder.Text = Settings.DefaultAddonFolder;
        Controls.Add(folder);

        var browse = new Button { Text = "Browse", Left = 475, Top = 139, Width = 90, Height = 27 };
        browse.Click += (s, e) => BrowseForFolder();
        Controls.Add(browse);

        update.Text = "Update now";
        update.SetBounds(20, 183, 145, 32);
        update.Click += async (s, e) => await RunUpdateAsync();
        Controls.Add(update);

        auto.Text = "Update every 30 minutes while open";
        auto.SetBounds(185, 188, 300, 24);
        auto.CheckedChanged += (s, e) =>
        {
            timer.Enabled = auto.Checked;
            SaveSettings();
        };
        Controls.Add(auto);

        status.SetBounds(20, 227, 550, 72);
        status.Text = "Choose your market, then click Update now. Reload the game after an update.";
        Controls.Add(status);

        timer.Interval = 30 * 60 * 1000;
        timer.Tick += async (s, e) => await RunUpdateAsync();

        LoadSettings();
        loading = false;
    }

    void AddLabel(string text, int x, int y)
    {
        Controls.Add(new Label { Text = text, Left = x, Top = y, Width = 180, Height = 20 });
    }

    void SetupComboBox(ComboBox box, int x, int y, int width, string[] items)
    {
        box.SetBounds(x, y, width, 25);
        box.DropDownStyle = ComboBoxStyle.DropDownList;
        box.Items.AddRange(items);
        box.SelectedIndex = 0;
        box.SelectedIndexChanged += (s, e) => SaveSettings();
        Controls.Add(box);
    }

    void BrowseForFolder()
    {
        using var dialog = new FolderBrowserDialog { Description = "Select your Marketeer addon folder" };
        if (dialog.ShowDialog() == DialogResult.OK)
        {
            folder.Text = dialog.SelectedPath;
        }
    }

    Market SelectedMarket()
    {
        return new Market(
            region.SelectedItem.ToString().ToLowerInvariant(),
            ruleset.SelectedItem.ToString().ToLowerInvariant().Replace(" ", ""),
            faction.SelectedItem.ToString().ToLowerInvariant());
    }

    void SaveSettings()
    {
        if (loading || region.SelectedItem == null || ruleset.SelectedItem == null || faction.SelectedItem == null)
        {
            return;
        }

        settings.Save(new SettingsData
        {
            Region = region.SelectedIndex,
            Ruleset = ruleset.SelectedIndex,
            Faction = faction.SelectedIndex,
            Folder = folder.Text,
            AutoUpdate = auto.Checked,
        });
    }

    void LoadSettings()
    {
        SettingsData data = settings.Load();
        if (data == null)
        {
            return;
        }

        SelectIndex(region, data.Region);
        SelectIndex(ruleset, data.Ruleset);
        SelectIndex(faction, data.Faction);
        if (data.Folder.Length > 0)
        {
            folder.Text = data.Folder;
        }

        if (data.AutoUpdate.HasValue)
        {
            auto.Checked = data.AutoUpdate.Value;
        }
    }

    static void SelectIndex(ComboBox box, int? index)
    {
        if (index is int value && value >= 0 && value < box.Items.Count)
        {
            box.SelectedIndex = value;
        }
    }

    async Task RunUpdateAsync()
    {
        update.Enabled = false;
        timer.Stop();
        status.Text = "Downloading market data...";

        Market market = SelectedMarket();
        string addonFolder = folder.Text.Trim();
        SaveSettings();

        try
        {
            string outcome = await Task.Run(() => DataUpdater.Update(market, addonFolder));
            status.Text = outcome
                + " If WoW is open, type /reload; otherwise start WoW. Enable Marketeer Data in AddOns."
                + " Prices from AHledger (ahledger.com).";
        }
        catch (UnauthorizedAccessException)
        {
            status.Text = "Update failed: Windows denied write access to the AddOns folder. "
                + "Give your Windows user write permission to the World of Warcraft folder "
                + "(Properties > Security), then try again. Previous data was kept.";
        }
        catch (Exception e)
        {
            status.Text = "Update failed: " + e.Message + ". Previous data was kept.";
        }
        finally
        {
            update.Enabled = true;
            if (auto.Checked)
            {
                timer.Start();
            }
        }
    }
}
