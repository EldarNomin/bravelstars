using System;
using Bravel.Sim;

namespace Bravel.Checks
{
    public static class SimulationChecks
    {
        static void Require(bool condition, string message) { if (!condition) throw new Exception(message); }
        static void Near(float a, float b, string message, float tolerance = 0.001f) => Require(Math.Abs(a - b) <= tolerance, message + $": {a} vs {b}");
        static World Open(Balance balance = null)
        {
            return new World(new ArenaMap(new MapData { mode = "teamfight", grid = new[] {
                "XXXXXXXXXXXXXXXXXXXX", "X..................X", "X.1..............2.X", "X..................X", "X..................X", "X..................X", "X..................X", "XXXXXXXXXXXXXXXXXXXX" } }), 42, balance ?? new Balance());
        }
        static void Advance(World w, int n) { for (int i = 0; i < n; i++) { w.Step(); w.Events.Clear(); } }
        public static void Run(HeroData[] heroes, Balance balance, MapData[] maps, Action<string> log)
        {
            int passed = 0;
            Action<string, Action> test = (name, body) => { body(); passed++; log("PASS " + name); };
            test("source balance and magazine pillar", () =>
            {
                Require(heroes[1].attack.damage == 330, "Current dev balance must be preserved");
                foreach (var h in heroes) Require(h.attack.damage * h.attack.projectile_count * h.max_ammo < h.max_hp, "Magazine kills own class: " + h.id);
            });
            test("all map data and mirrored roster", () =>
            {
                foreach (var data in maps)
                {
                    var m = new ArenaMap(data); Require(m.Spawns[0].Count > 0 && m.Spawns[1].Count > 0, "Spawns missing");
                    var match = new Match(data, heroes, balance, 0, 1, 1);
                    Require(match.World.Brawlers.Count == 6 && match.Bots.Length == 5, "3v3 roster");
                    if (data.development) continue;
                    for (int i = 0; i < 3; i++)
                    {
                        var a = match.World.Brawlers[i]; var b = match.World.Brawlers[i + 3];
                        Near(a.Spawn.X + b.Spawn.X, m.Width, "Mirror X"); Near(a.Spawn.Y + b.Spawn.Y, m.Height, "Mirror Y");
                    }
                }
                bool rejected = false;
                try { new ArenaMap(new MapData { grid = new[] { "XXX", "X?X", "XXX" } }); } catch (ArgumentException) { rejected = true; }
                Require(rejected, "Invalid tile accepted");
            });
            test("bounded movement and swept wall collision", () =>
            {
                var w = Open(); var b = w.Add(heroes[0], 0); var before = b.Position;
                w.Input(b, new Command { Move = new Vec(100, 100) }); w.Step(); Near(Vec.Distance(before, b.Position), b.Data.move_speed * World.Dt, "Diagonal normalized");
                w.Move(b, new Vec(-100, 0)); Require(b.Position.X >= 1 + b.Data.radius - 0.001f, "Tunneled through boundary");
                w.Step(); Near(b.Position.Y, before.Y + b.Data.move_speed * World.Dt / (float)Math.Sqrt(2), "Input must expire after tick");
            });
            test("shared shot ID and swept projectile hits", () =>
            {
                var w = Open(); var a = w.Add(heroes[1], 0, new Vec(3, 3)); var b = w.Add(heroes[1], 1, new Vec(4, 3));
                w.Fire(a, a.Data.attack, new Vec(1, 0), false); int id = w.Projectiles[0].AttackId;
                Require(w.Projectiles.Count == 5, "Pellets"); foreach (var p in w.Projectiles) Require(p.AttackId == id, "Pellets need one shot ID");
                for (int i = 0; i < 10; i++) w.Step();
                Require(b.Hp < b.Data.max_hp, "No projectile damage");
                bool hit = false; foreach (var e in w.Events) if (e.Kind == EventKind.Hit) { Require(e.AttackId == id, "Hit attribution"); hit = true; }
                Require(hit, "Event lost between ticks");
                var events = new System.Collections.Generic.List<SimEvent>(); w.DrainEvents(events); Require(events.Count > 0 && w.Events.Count == 0, "Drain must consume");
            });
            test("piercing hits each target once", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0, new Vec(3, 3)); var b = w.Add(heroes[1], 1, new Vec(5, 3)); var c = w.Add(heroes[1], 1, new Vec(7, 3));
                w.Fire(a, a.Data.super_attack, new Vec(1, 0), true); Advance(w, 15);
                Require(b.Hp == b.Data.max_hp - 1800 && c.Hp == c.Data.max_hp - 1800, "Pierce must hit both once"); Require(a.SuperCharge == 0, "Super cannot charge itself");
            });
            test("lob crosses walls and honors minimum range", () =>
            {
                var w = Open(); var a = w.Add(heroes[2], 0, new Vec(3, 3)); var b = w.Add(heroes[1], 1, new Vec(6, 3));
                w.Map.Set(3 * w.Map.Width + 4, Tile.Wall); w.Fire(a, a.Data.attack, new Vec(3, 0), false);
                Advance(w, World.Seconds(a.Data.attack.flight_time)); Require(b.Hp == b.Data.max_hp - 750, "Lob blocked");
                w.Fire(a, a.Data.attack, new Vec(0.1f, 0), false); Near(Vec.Distance(w.Projectiles[0].Target, a.Position), 2, "Min lob range");
            });
            test("ammo reload and attack cooldown", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0); w.Input(a, new Command { Attack = true }); w.Step();
                Require(a.Ammo == 2, "Shot cost"); w.Input(a, new Command { Attack = true }); w.Step(); Require(a.Ammo == 2, "Cooldown ignored");
                Advance(w, World.Seconds(a.Data.reload_time) - 2); Require(a.Ammo == 3, "Reload missing");
            });
            test("regen delay and fractional healing", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0); w.Damage(a, 1000, null, null, false, default);
                Advance(w, World.Seconds(balance.regen_delay)); Require(a.Hp == a.Data.max_hp - 1000, "Early regen");
                Advance(w, 30); Near(a.Hp, a.Data.max_hp - 1000 + a.Data.max_hp * balance.regen_percent_per_sec, "Regen amount", 1);
            });
            test("death preserves super, respawn shields, firing cancels shield", () =>
            {
                var w = Open(balance); var a = w.Add(heroes[0], 0); a.SuperCharge = 700;
                w.Damage(a, 99999, null, null, false, default); Require(!a.Alive && a.SuperCharge == 700, "Death rules");
                Advance(w, World.Seconds(balance.respawn_time) + 1); Require(a.Alive && a.Hp == a.Data.max_hp && a.Position.X == a.Spawn.X, "Respawn");
                w.Damage(a, 100, null, null, false, default); Require(a.Hp == a.Data.max_hp, "Spawn shield");
                w.Input(a, new Command { Attack = true }); w.Step(); w.Damage(a, 100, null, null, false, default); Require(a.Hp == a.Data.max_hp - 100, "Shield after firing");
            });
            test("knockback is gradual and dash resets on death", () =>
            {
                var w = Open(); var a = w.Add(heroes[1], 0, new Vec(3, 3)); var b = w.Add(heroes[1], 1, new Vec(6, 3));
                w.Damage(b, 1, a, a.Data.super_attack, true, a.Position); Near(b.Position.X, 6, "Knockback teleported");
                Advance(w, World.Seconds(balance.knockback_duration)); Near(b.Position.X, 7.5f, "Knockback distance");
                a.SuperCharge = 1000; w.Input(a, new Command { Super = true, SuperAim = new Vec(1, 0) }); w.Step(); Require(a.DashTicks > 0, "Dash absent");
                w.Damage(a, 99999, null, null, false, default); Require(a.DashTicks == 0, "Dash survived death"); Advance(w, 125); Require(a.DashTicks == 0, "Dash resumed on respawn");
            });
            test("bush visibility, destruction and regrowth", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0, new Vec(3, 3)); var b = w.Add(heroes[1], 1, new Vec(10.5f, 3.5f));
                w.Map.Set(w.Map.Cell(b.Position), Tile.Bush); Require(!w.Visible(0, b) && w.Visible(1, b), "Bush visibility");
                w.Fire(b, b.Data.attack, new Vec(1, 0), false); Require(w.Visible(0, b), "Shooting must reveal");
                w.DestroyAt(b.Position); Require(w.Map.At(b.Position) == Tile.Floor, "Bush destruction");
                Advance(w, World.Seconds(balance.bush_regrow_time) + 1); Require(w.Map.At(b.Position) == Tile.Bush, "Bush regrowth");
                w.Map.Set(w.Map.Cell(a.Position), Tile.Wall); w.DestroyAt(a.Position); Advance(w, 400); Require(w.Map.At(a.Position) == Tile.Floor, "Wall regrew");
            });
            test("countdown rejects commands and match result freezes", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0); var b = w.Add(heroes[0], 1); w.Mode = new MatchMode(w.Map, false);
                w.Input(a, new Command { Attack = true }); w.Step(); Require(a.Ammo == 3 && w.Projectiles.Count == 0, "Countdown fired");
                Advance(w, 89); Require(w.Mode.Phase == MatchPhase.Playing, "Countdown length");
                for (int i = 0; i < 10; i++) { b.Reset(); w.Damage(b, 9999, a, a.Data.attack, false, a.Position); }
                Require(w.Mode.Phase == MatchPhase.Finished && w.Mode.Winner == 0 && w.Mode.Scores[0] == 10, "Score victory");
                int tick = w.Tick; Advance(w, 30); Require(w.Tick == tick, "Finished simulation advanced");
            });
            test("heist pickup, deposit, visibility, slowdown and death drop", () =>
            {
                var w = Open(); var a = w.Add(heroes[0], 0); w.Mode = new MatchMode(w.Map, true); Advance(w, 90);
                a.Position = new Vec(6, 3); w.Mode.Shards.Add(a.Position); w.Step(); Require(a.Carried == 1, "Pickup");
                w.Map.Set(w.Map.Cell(a.Position), Tile.Bush); Require(w.Visible(1, a), "Carrier concealed");
                Vec before = a.Position; w.Input(a, new Command { Move = new Vec(1, 0) }); w.Step(); Near(Vec.Distance(before, a.Position), a.Data.move_speed * 0.85f / 30, "Carrier slowdown");
                a.Position = w.Mode.Safes[0]; w.Step(); Require(a.Carried == 0 && w.Mode.Scores[0] == 1, "Deposit");
                a.Carried = 3; int count = w.Mode.Shards.Count; w.Damage(a, 99999, null, null, false, default);
                Require(a.Carried == 0 && w.Mode.Shards.Count == count + 3, "Death must drop shards");
            });
            test("seeded bot matches finish identically on all shipping maps", () =>
            {
                int runs = 0, shots = 0, hits = 0, deposits = 0;
                foreach (var map in maps)
                {
                    if (map.development) continue;
                    for (int seed = 1; seed <= 3; seed++)
                    {
                        var a = new Match(map, heroes, balance, 0, 1, seed, true); var b = new Match(map, heroes, balance, 0, 1, seed, true);
                        for (int tick = 0; tick < 4600 && a.World.Mode.Phase != MatchPhase.Finished; tick++)
                        {
                            a.Step(default); b.Step(default);
                            Require(Hash(a.World) == Hash(b.World), "Replay divergence: " + map.name + " tick " + tick);
                            foreach (var e in a.World.Events) { if (e.Kind == EventKind.Attack) shots++; if (e.Kind == EventKind.Hit) hits++; if (e.Kind == EventKind.Deposit) deposits++; }
                            foreach (var hero in a.World.Brawlers) Require(!float.IsNaN(hero.Position.X) && !ArenaMap.BlocksMovement(a.World.Map.At(hero.Position)), "Bot inside blocked cell");
                            a.World.Events.Clear(); b.World.Events.Clear();
                        }
                        Require(a.World.Mode.Phase == MatchPhase.Finished, "Match did not finish"); runs++;
                    }
                }
                Require(shots > 100 && hits > 50 && deposits > 0, "Bots did not exercise combat/objectives");
                log($"BOT_MATCHES {runs} pairs, {shots} attacks, {hits} hits, {deposits} deposits");
            });
            test("simulation hot loop does not allocate after warmup", () =>
            {
                var match = new Match(maps[0], heroes, balance, 0, 2, 11, true); match.World.Mode = null;
                for (int i = 0; i < 1000; i++) { match.Step(default); match.World.Events.Clear(); }
                long before = GC.GetAllocatedBytesForCurrentThread();
                for (int i = 0; i < 1000; i++) { match.Step(default); match.World.Events.Clear(); }
                long allocated = GC.GetAllocatedBytesForCurrentThread() - before;
                Require(allocated == 0, "Core allocated: " + allocated); log("CORE_ALLOCATED_BYTES " + allocated);
            });
            log($"SIMULATION_CHECKS_PASSED {passed}");
        }
        static ulong Hash(World w)
        {
            ulong h = 14695981039346656037;
            foreach (var b in w.Brawlers)
            {
                h = Mix(h, b.Hp); h = Mix(h, b.Ammo); h = Mix(h, b.SuperCharge); h = Mix(h, b.Carried); h = Mix(h, b.DashTicks);
                h = Mix(h, BitConverter.SingleToInt32Bits(b.Position.X)); h = Mix(h, BitConverter.SingleToInt32Bits(b.Position.Y));
            }
            foreach (var p in w.Projectiles) { h = Mix(h, p.Id); h = Mix(h, p.Age); h = Mix(h, BitConverter.SingleToInt32Bits(p.Position.X)); h = Mix(h, BitConverter.SingleToInt32Bits(p.Position.Y)); }
            foreach (var t in w.Map.Tiles) h = Mix(h, (int)t);
            foreach (var e in w.Events) { h = Mix(h, (int)e.Kind); h = Mix(h, e.Actor); h = Mix(h, e.Target); h = Mix(h, e.Amount); }
            return h;
        }
        static ulong Mix(ulong h, int n) => unchecked((h ^ (uint)n) * 1099511628211);
    }
}
