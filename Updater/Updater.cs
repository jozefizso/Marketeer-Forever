using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using System.Threading.Tasks;
using System.IO.Compression;
using System.Diagnostics;

static class Program {
 [STAThread] static void Main(){Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new Updater());}
}
sealed class Updater : Form {
 ComboBox region=new ComboBox(),ruleset=new ComboBox(),faction=new ComboBox();
 TextBox folder=new TextBox(); Label status=new Label(); Button update=new Button(); CheckBox auto=new CheckBox(); Timer timer=new Timer();
 bool loading=true;
 string cacheDir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"MarketeerForeverUpdater");
 string settings { get { return Path.Combine(cacheDir,"settings.txt"); } }
 public Updater(){
  Text="Marketeer Data Updater";ClientSize=new Size(590,320);FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;
  Controls.Add(new Label{Text="AHledger market data for Marketeer",Left=20,Top=15,Width=540,Height=24,Font=new Font(Font,FontStyle.Bold)});
  AddLabel("Region",20,53);AddLabel("Ruleset",175,53);AddLabel("Faction",365,53);
  Setup(region,20,75,140,new[]{"US","EU","CN"});Setup(ruleset,175,75,175,new[]{"Normal","PvP","RP","RP PvP"});Setup(faction,365,75,200,new[]{"Alliance","Horde"});
  AddLabel("Marketeer addon folder",20,118);folder.SetBounds(20,141,445,25);folder.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),@"World of Warcraft\_forever_\Interface\AddOns\MarketeerForever");Controls.Add(folder);
  Button browse=new Button{Text="Browse",Left=475,Top=139,Width=90,Height=27};browse.Click+=(s,e)=>{using(var dialog=new FolderBrowserDialog()){dialog.Description="Select your Marketeer addon folder";if(dialog.ShowDialog()==DialogResult.OK)folder.Text=dialog.SelectedPath;}};Controls.Add(browse);
  update.Text="Update now";update.SetBounds(20,183,145,32);update.Click+=async(s,e)=>await RunUpdate();Controls.Add(update);
  auto.Text="Update every 30 minutes while open";auto.SetBounds(185,188,300,24);auto.CheckedChanged+=(s,e)=>{timer.Enabled=auto.Checked;SaveSettings();};Controls.Add(auto);
  status.SetBounds(20,227,550,72);status.Text="Choose your market, then click Update now. Reload the game after an update.";Controls.Add(status);
  
  timer.Interval=30*60*1000;timer.Tick+=async(s,e)=>await RunUpdate(); LoadSettings(); loading=false;
 }
 void AddLabel(string text,int x,int y){Controls.Add(new Label{Text=text,Left=x,Top=y,Width=180,Height=20});}
 void Setup(ComboBox box,int x,int y,int w,string[] items){box.SetBounds(x,y,w,25);box.DropDownStyle=ComboBoxStyle.DropDownList;box.Items.AddRange(items);box.SelectedIndex=0;box.SelectedIndexChanged+=(s,e)=>SaveSettings();Controls.Add(box);}
 string MarketRegion(){return region.SelectedItem.ToString().ToLowerInvariant();}
 string Ruleset(){return ruleset.SelectedItem.ToString().ToLowerInvariant().Replace(" ","");}
 string Faction(){return faction.SelectedItem.ToString().ToLowerInvariant();}
 void SaveSettings(){try{if(loading)return;if(region.SelectedItem==null||ruleset.SelectedItem==null||faction.SelectedItem==null)return;Directory.CreateDirectory(cacheDir);File.WriteAllLines(settings,new[]{region.SelectedIndex.ToString(),ruleset.SelectedIndex.ToString(),faction.SelectedIndex.ToString(),folder.Text,auto.Checked.ToString()});}catch{}}
 void LoadSettings(){try{string path=settings;if(!File.Exists(path)){path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NokiTradingUpdater","settings.txt");if(!File.Exists(path))return;}string[] a=File.ReadAllLines(path);if(a.Length<5)return;int n;if(int.TryParse(a[0],out n)&&n>=0&&n<region.Items.Count)region.SelectedIndex=n;if(int.TryParse(a[1],out n)&&n>=0&&n<ruleset.Items.Count)ruleset.SelectedIndex=n;if(int.TryParse(a[2],out n)&&n>=0&&n<faction.Items.Count)faction.SelectedIndex=n;if(a[3].Length>0){string previous=a[3].TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);folder.Text=Path.GetFileName(previous).Equals("NokiTrading",StringComparison.OrdinalIgnoreCase)?Path.Combine(Directory.GetParent(previous).FullName,"MarketeerForever"):a[3];}bool v;if(bool.TryParse(a[4],out v))auto.Checked=v;}catch{}}
 async Task RunUpdate(){
  update.Enabled=false;timer.Stop();status.Text="Downloading market data...";
  string reg=MarketRegion(),rule=Ruleset(),fact=Faction(),dir=folder.Text.Trim();SaveSettings();
  try{string outcome=await Task.Run(()=>{int count=FetchAndWrite(reg,rule,fact,dir);string result="Updated "+count+" items.";try{int trends=FetchTrends(reg,rule,fact,dir);result+=" Trends: "+trends+".";}catch(Exception e){result+=" Trends unavailable: "+e.Message+"; previous kept.";}try{int history=FetchHistory(reg,rule,fact,dir);result+=" History: "+history+".";}catch(Exception e){result+=" History unavailable: "+e.Message+"; previous kept.";}return result;});status.Text=outcome+" If WoW is open, type /reload; otherwise start WoW. Enable Marketeer Data in AddOns. Prices from AHledger (ahledger.com).";}
  catch(Exception e){status.Text="Update failed: "+e.Message+". Previous data was kept.";}
  finally{update.Enabled=true;if(auto.Checked)timer.Start();}
 }
 int FetchAndWrite(string reg,string rule,string fact,string dir){
  string tocName="MarketeerForever.toc";
  if(!File.Exists(Path.Combine(dir,tocName)))throw new Exception("Select the Marketeer addon folder");
  string toc=File.ReadAllText(Path.Combine(dir,tocName));if(!toc.Contains("MarketeerForeverData"))throw new Exception("Install a compatible Marketeer addon first");
  var addons=Directory.GetParent(Path.GetFullPath(dir));if(addons==null || !addons.Name.Equals("AddOns",StringComparison.OrdinalIgnoreCase))throw new Exception("Select the Marketeer folder inside Interface/AddOns");
  var match=Regex.Match(toc,@"(?m)^##\s*Interface:\s*(\d+)");if(!match.Success)throw new Exception("Cannot determine interface version");
  string dataDir=Path.Combine(addons.FullName,"MarketeerForeverData");
  string url="https://devvy.xyz/marketeer/market-data.php?region="+reg+"&ruleset="+rule+"&faction="+fact;
  ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
  string text;using(var client=new WebClient()){client.Headers.Add(HttpRequestHeader.UserAgent,"MarketeerForeverUpdater/1.0");text=client.DownloadString(url);}
  string market="forever/"+rule+"/"+fact+"/"+reg; Validate(text,market);
  Directory.CreateDirectory(cacheDir);string key=rule+"_"+fact+"_"+reg;File.WriteAllText(Path.Combine(cacheDir,key+".txt"),text,new UTF8Encoding(false));
  var result=new StringBuilder("-- AHledger data generated by Marketeer Data Updater.\n_G.MarketeerForeverMarketData = {schemaVersion=1,periodHours=24,generatedAt="+DateTimeOffset.UtcNow.ToUnixTimeSeconds()+",tables={\n");int count=0;
  foreach(string file in Directory.GetFiles(cacheDir,"*.txt")){
   string name=Path.GetFileNameWithoutExtension(file);if(!Regex.IsMatch(name,@"^(normal|pvp|rp|rppvp)_(alliance|horde)_(us|eu|cn)$"))continue;
   string[] parts=name.Split('_');string m="forever/"+parts[0]+"/"+parts[1]+"/"+parts[2];string item=File.ReadAllText(file);string[] parsed=Validate(item,m);if(m==market)count=int.Parse(parsed[2]);
   result.Append("[\"").Append(m).Append("\"]={updated=").Append(parsed[1]).Append(",count=").Append(parsed[2]).Append(",text=[==[\n").Append(parsed[3]).Append("\n]==]},\n");
  }
  result.Append("}}\n");Directory.CreateDirectory(dataDir);
  string target=Path.Combine(dataDir,"MarketData.lua"),tmp=target+".tmp";
  try{File.WriteAllText(tmp,result.ToString(),new UTF8Encoding(false));if(File.ReadAllText(tmp)!=result.ToString())throw new Exception("Data validation failed");if(File.Exists(target))File.Replace(tmp,target,null);else File.Move(tmp,target);}finally{if(File.Exists(tmp))File.Delete(tmp);}
  string dataToc=Path.Combine(dataDir,"MarketeerForeverData.toc"),tocTmp=dataToc+".tmp";
  string trendPath=Path.Combine(dataDir,"TrendData.lua");if(!File.Exists(trendPath))File.WriteAllText(trendPath,"-- Trend data not yet available.\n",new UTF8Encoding(false));
  string historyPath=Path.Combine(dataDir,"HistoryData.lua");if(!File.Exists(historyPath))File.WriteAllText(historyPath,"-- Price history not yet available.\n",new UTF8Encoding(false));
  try{File.WriteAllText(tocTmp,"## Interface: "+match.Groups[1].Value+"\n## Title: Marketeer Data\n## Notes: AHledger data\nMarketData.lua\nTrendData.lua\nHistoryData.lua\n",new UTF8Encoding(false));if(File.Exists(dataToc))File.Replace(tocTmp,dataToc,null);else File.Move(tocTmp,dataToc);}finally{if(File.Exists(tocTmp))File.Delete(tocTmp);}return count;
 }
 int FetchHistory(string reg,string rule,string fact,string dir){
  string market="forever/"+rule+"/"+fact+"/"+reg;
  string url="https://devvy.xyz/marketeer/history-export.php?market="+Uri.EscapeDataString(market);
  string text;using(var client=new WebClient()){client.Headers.Add(HttpRequestHeader.UserAgent,"MarketeerForeverDataUpdater/1.0");text=client.DownloadString(url);}
  if(text.Length>20000000)throw new Exception("History data is too large");
  string[] lines=text.Replace("\r","").TrimEnd('\n').Split('\n');string[] h=lines[0].Split('|');long generated;int count;
  if(h.Length!=4||h[0]!="HST1"||h[1]!=market||!long.TryParse(h[2],out generated)||generated<=0||generated>DateTimeOffset.UtcNow.ToUnixTimeSeconds()+300||!int.TryParse(h[3],out count)||count<0||count>100000||lines.Length!=count+1)throw new Exception("Invalid history header");
  var result=new StringBuilder("-- AHledger hourly lows and older daily medians.\n_G.MarketeerForeverHistory={schemaVersion=1,market=\"").Append(market).Append("\",generatedAt=").Append(generated).Append(",items={\n");
  var seen=new HashSet<int>();
  for(int i=1;i<lines.Length;i++){
   int colon=lines[i].IndexOf(':');int id;if(colon<=0||!int.TryParse(lines[i].Substring(0,colon),out id)||id<=0||!seen.Add(id))throw new Exception("Invalid history item");
   string points=lines[i].Substring(colon+1);string[] entries=points.Split(';');if(entries.Length<1||entries.Length>400)throw new Exception("Invalid history count");int previous=337;
   foreach(string entry in entries){string[] fields=entry.Split(',');int age;long price;if(fields.Length!=2||!int.TryParse(fields[0],out age)||age<0||age>336||age>=previous||!long.TryParse(fields[1],out price)||price<=0||price>2000000000000L||!Regex.IsMatch(entry,@"^\d+,\d+$"))throw new Exception("Invalid history point");previous=age;}
   result.Append('[').Append(id).Append("] = \"").Append(points).Append("\",\n");
  }
  result.Append("}}\n");string target=Path.Combine(Directory.GetParent(Path.GetFullPath(dir)).FullName,"MarketeerForeverData","HistoryData.lua"),tmp=target+".tmp";
  try{File.WriteAllText(tmp,result.ToString(),new UTF8Encoding(false));if(File.ReadAllText(tmp)!=result.ToString())throw new Exception("History validation failed");if(File.Exists(target))File.Replace(tmp,target,null);else File.Move(tmp,target);}finally{if(File.Exists(tmp))File.Delete(tmp);}return count;
 }
 int FetchTrends(string reg,string rule,string fact,string dir){
  string market="forever/"+rule+"/"+fact+"/"+reg;
  string url="https://devvy.xyz/marketeer/trends-export-v2.php?market="+Uri.EscapeDataString(market);
  string text;using(var client=new WebClient()){client.Headers.Add(HttpRequestHeader.UserAgent,"MarketeerForeverDataUpdater/1.0");text=client.DownloadString(url);}
  if(text.Length>4000000)throw new Exception("Trend data is too large");
  string[] lines=text.Replace("\r","").TrimEnd('\n').Split('\n');string[] h=lines[0].Split('|');long generated;int count;
  if(h.Length!=4||h[0]!="TRD2"||h[1]!=market||!long.TryParse(h[2],out generated)||generated<=0||generated>DateTimeOffset.UtcNow.ToUnixTimeSeconds()+300||!int.TryParse(h[3],out count)||count<0||count>100000||lines.Length!=count+1)throw new Exception("Invalid trend header");
  var result=new StringBuilder("-- AHledger low-price trend summaries.\n_G.MarketeerForeverTrends={schemaVersion=2,market=\"").Append(market).Append("\",generatedAt=").Append(generated).Append(",items={\n");
  var seen=new HashSet<string>();
  for(int i=1;i<lines.Length;i++){
   if(!Regex.IsMatch(lines[i],@"^[1-9]\d*:\d*:\d*:\d*:\d*:\d+$"))throw new Exception("Invalid trend row");
   string[] p=lines[i].Split(':');long item,last;long value;
   if(!long.TryParse(p[0],out item)||item>2147483647||!seen.Add(p[0])||!long.TryParse(p[5],out last)||last<=0||last>generated+300)throw new Exception("Invalid trend item");
   for(int j=1;j<=4;j++)if(p[j].Length>0&&(!long.TryParse(p[j],out value)||value<=0||value>2000000000000L))throw new Exception("Invalid trend price");
   result.Append('[').Append(p[0]).Append("]={");for(int j=1;j<=4;j++)result.Append(p[j].Length==0?"false":p[j]).Append(',');result.Append(p[5]).Append("},\n");
  }
  result.Append("}}\n");string target=Path.Combine(Directory.GetParent(Path.GetFullPath(dir)).FullName,"MarketeerForeverData","TrendData.lua"),tmp=target+".tmp";
  try{File.WriteAllText(tmp,result.ToString(),new UTF8Encoding(false));if(File.ReadAllText(tmp)!=result.ToString())throw new Exception("Trend data validation failed");if(File.Exists(target))File.Replace(tmp,target,null);else File.Move(tmp,target);}finally{if(File.Exists(tmp))File.Delete(tmp);}return count;
 }
 static string[] Validate(string text,string market){
  if(text.Length>2000000)throw new Exception("Data is too large");text=text.Replace("\r","");int i=text.IndexOf('\n');if(i<0)throw new Exception("Invalid AHledger table");string[] h=text.Substring(0,i).Split('|');long ts;int count;
  if(h.Length!=4||h[0]!="AHL1"||h[1]!=market||!long.TryParse(h[2],out ts)||ts<=0||ts>DateTimeOffset.UtcNow.ToUnixTimeSeconds()+300||!int.TryParse(h[3],out count)||count<1||count>100000)throw new Exception("Invalid market or table header");
  string body=text.Substring(i+1).Trim();string[] lines=body.Split('\n');if(lines.Length!=count)throw new Exception("Incomplete market table");foreach(string row in lines)if(!Regex.IsMatch(row,@"^\d+(?::\d*){8}$"))throw new Exception("Invalid market row");return new[]{market,h[2],h[3],body};
 }

}
