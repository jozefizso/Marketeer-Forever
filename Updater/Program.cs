using System;
using System.Net;
using System.Windows.Forms;

namespace MarketeerForever.Updater;

static class Program
{
    [STAThread]
    static void Main()
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new UpdaterForm());
    }
}
