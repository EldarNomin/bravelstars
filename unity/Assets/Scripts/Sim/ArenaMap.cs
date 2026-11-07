using System;
using System.Collections.Generic;

namespace Bravel.Sim
{
    [Serializable]
    public sealed class MapData { public string name, mode, author; public string[] grid; public bool development; }
    public enum Tile : byte { Floor, Wall, HardWall, Bush, Water }

    public sealed class ArenaMap
    {
        public readonly int Width, Height;
        public readonly MapData Data;
        public readonly Tile[] Tiles;
        public readonly List<Vec>[] Spawns = { new List<Vec>(), new List<Vec>() };
        public readonly Dictionary<char, Vec> Markers = new Dictionary<char, Vec>();
        public int Version { get; private set; }
        public ArenaMap(MapData data)
        {
            if (data?.grid == null || data.grid.Length < 3 || data.grid[0].Length < 3) throw new ArgumentException("Map grid is missing or too small");
            Data = data; Height = data.grid.Length; Width = data.grid[0].Length; Tiles = new Tile[Width * Height];
            for (int y = 0; y < Height; y++)
            {
                if (data.grid[y].Length != Width) throw new ArgumentException("Ragged map: " + data.name);
                for (int x = 0; x < Width; x++)
                {
                    char c = data.grid[y][x]; Vec at = new Vec(x + 0.5f, y + 0.5f); Tile tile;
                    switch (c)
                    {
                        case '.': tile = Tile.Floor; break;
                        case '#': tile = Tile.Wall; break;
                        case 'X': tile = Tile.HardWall; break;
                        case '*': tile = Tile.Bush; break;
                        case '~': tile = Tile.Water; break;
                        case '1': case '2': tile = Tile.Floor; Spawns[c - '1'].Add(at); break;
                        default:
                            if (c < 'A' || c > 'Z') throw new ArgumentException("Unknown map cell: " + c);
                            tile = Tile.Floor; Markers[c] = at; break;
                    }
                    Tiles[y * Width + x] = tile;
                }
            }
        }
        public bool Inside(int x, int y) => x >= 0 && y >= 0 && x < Width && y < Height;
        public Tile Get(int x, int y) => Inside(x, y) ? Tiles[y * Width + x] : Tile.HardWall;
        public Tile At(Vec p) => Get((int)Math.Floor(p.X), (int)Math.Floor(p.Y));
        public int Cell(Vec p) => (int)Math.Floor(p.Y) * Width + (int)Math.Floor(p.X);
        public Vec Center(int cell) => new Vec(cell % Width + 0.5f, cell / Width + 0.5f);
        public void Set(int cell, Tile tile) { if (cell < 0 || cell >= Tiles.Length) return; Tiles[cell] = tile; Version++; }
        public static bool BlocksMovement(Tile t) => t == Tile.Wall || t == Tile.HardWall || t == Tile.Water;
        public static bool BlocksShot(Tile t) => t == Tile.Wall || t == Tile.HardWall;
        public bool Walkable(int x, int y) => Inside(x, y) && !BlocksMovement(Get(x, y));
        public Vec Resolve(Vec p, float radius)
        {
            for (int pass = 0; pass < 3; pass++)
            {
                bool moved = false;
                int x0 = (int)Math.Floor(p.X - radius), x1 = (int)Math.Floor(p.X + radius);
                int y0 = (int)Math.Floor(p.Y - radius), y1 = (int)Math.Floor(p.Y + radius);
                for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
                {
                    if (!BlocksMovement(Get(x, y))) continue;
                    var near = new Vec(Vec.Clamp(p.X, x, x + 1), Vec.Clamp(p.Y, y, y + 1));
                    var diff = p - near; float dist = diff.Length;
                    if (dist >= radius) continue;
                    if (dist > 0.0001f) p += diff / dist * (radius - dist);
                    else
                    {
                        float l = p.X - x, r = x + 1 - p.X, t = p.Y - y, b = y + 1 - p.Y;
                        float min = Math.Min(Math.Min(l, r), Math.Min(t, b));
                        if (min == l) p.X = x - radius;
                        else if (min == r) p.X = x + 1 + radius;
                        else if (min == t) p.Y = y - radius;
                        else p.Y = y + 1 + radius;
                    }
                    moved = true;
                }
                if (!moved) break;
            }
            return p;
        }
        public bool Line(Vec a, Vec b, float margin = 0, bool walking = false)
        {
            if (margin > 0)
            {
                var d = (b - a).Normalized; var side = new Vec(-d.Y, d.X) * margin;
                return Line(a, b, 0, walking) && Line(a + side, b + side, 0, walking) && Line(a - side, b - side, 0, walking);
            }
            int n = Math.Max(1, (int)Math.Ceiling(Vec.Distance(a, b) / 0.1f));
            for (int i = 1; i <= n; i++)
            {
                var t = At(Vec.Lerp(a, b, (float)i / n));
                if (walking ? BlocksMovement(t) : BlocksShot(t)) return false;
            }
            return true;
        }
    }
}
