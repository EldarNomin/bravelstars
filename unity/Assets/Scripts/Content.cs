using System;
using System.Collections.Generic;
using UnityEngine;
using Bravel.Sim;

namespace Bravel
{
    public sealed class Content
    {
        public readonly HeroData[] Heroes = new HeroData[3];
        public readonly Balance Balance;
        public readonly MapData[] Maps;
        public Content()
        {
            int i = 0;
            foreach (string id in new[] { "lynx", "anvil", "shishka" }) Heroes[i++] = Read<HeroData>("Data/Heroes/" + id);
            Balance = Read<Balance>("Data/balance");
            var maps = new List<MapData>();
            foreach (var json in Resources.LoadAll<TextAsset>("Data/Maps"))
            {
                var map = JsonUtility.FromJson<MapData>(json.text);
                if (map.development) continue;
                new ArenaMap(map); maps.Add(map);
            }
            maps.Sort((a, b) => string.Compare(a.name, b.name, StringComparison.Ordinal)); Maps = maps.ToArray();
            if (Maps.Length != 4) throw new InvalidOperationException("Expected four shipping maps");
        }
        static T Read<T>(string path)
        {
            var json = Resources.Load<TextAsset>(path);
            if (json == null) throw new InvalidOperationException("Missing content: " + path);
            return JsonUtility.FromJson<T>(json.text);
        }
    }
}
