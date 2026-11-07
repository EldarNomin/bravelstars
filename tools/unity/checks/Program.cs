using System;
using System.IO;
using System.Text.Json;
using Bravel.Sim;
using Bravel.Checks;

class Program
{
    static int Main(string[] args)
    {
        try
        {
            string root = args.Length > 0 ? Path.GetFullPath(args[0]) : Path.GetFullPath("unity/Assets/Resources/Data");
            var options = new JsonSerializerOptions { IncludeFields = true };
            var heroes = new HeroData[3]; int i = 0;
            foreach (string id in new[] { "lynx", "anvil", "shishka" }) heroes[i++] = JsonSerializer.Deserialize<HeroData>(File.ReadAllText(Path.Combine(root, "Heroes", id + ".json")), options);
            var balance = JsonSerializer.Deserialize<Balance>(File.ReadAllText(Path.Combine(root, "balance.json")), options);
            var paths = Directory.GetFiles(Path.Combine(root, "Maps"), "*.json"); Array.Sort(paths, StringComparer.Ordinal);
            var maps = Array.ConvertAll(paths, p => JsonSerializer.Deserialize<MapData>(File.ReadAllText(p), options));
            SimulationChecks.Run(heroes, balance, maps, Console.WriteLine); return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
    }
}
