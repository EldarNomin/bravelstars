using System;
using System.Collections.Generic;

namespace Bravel.Sim
{
    public enum MatchPhase { Countdown, Playing, Finished }
    public sealed class MatchMode
    {
        public MatchPhase Phase { get; private set; }
        public readonly bool Heist;
        public readonly int Target, Duration;
        public readonly int[] Scores = new int[2];
        public readonly Vec[] Safes = new Vec[2];
        public readonly Vec Mine;
        public readonly List<Vec> Shards = new List<Vec>(64);
        public int Countdown = World.Seconds(3), TicksLeft, Winner = -1;
        int nextShard;
        public MatchMode(ArenaMap map, bool heist)
        {
            Heist = heist; Target = heist ? 12 : 10; Duration = TicksLeft = World.Seconds(heist ? 150 : 120);
            Mine = map.Markers.TryGetValue('G', out var p) ? p : new Vec(map.Width * 0.5f, map.Height * 0.5f);
            for (int t = 0; t < 2; t++) Safes[t] = map.Markers.TryGetValue(t == 0 ? 'A' : 'B', out p) ? p : map.Spawns[t].Count > 0 ? map.Spawns[t][0] : Mine;
        }
        public void Step(World world)
        {
            if (Phase == MatchPhase.Countdown)
            {
                if (world.Tick + 1 >= Countdown) { Phase = MatchPhase.Playing; nextShard = world.Tick + 1; world.Emit(new SimEvent { Kind = EventKind.MatchStart }); }
                return;
            }
            if (Phase != MatchPhase.Playing) return;
            TicksLeft--;
            if (Heist) UpdateHeist(world);
            if (Phase == MatchPhase.Playing && TicksLeft <= 0) Finish(world, Scores[0] == Scores[1] ? -1 : Scores[0] > Scores[1] ? 0 : 1);
        }
        void UpdateHeist(World world)
        {
            if (world.Tick >= nextShard)
            {
                nextShard = world.Tick + World.Seconds(7);
                Shards.Add(Mine + new Vec(world.Rng.Range(-0.6f, 0.6f), world.Rng.Range(-0.6f, 0.6f)));
            }
            foreach (var b in world.Brawlers)
            {
                if (!b.Alive) continue;
                for (int i = Shards.Count - 1; i >= 0; i--) if (Vec.Distance(Shards[i], b.Position) <= 0.7f + b.Data.radius)
                {
                    b.Carried++; Shards.RemoveAt(i); world.Emit(new SimEvent { Kind = EventKind.Pickup, Actor = b.Id, Position = b.Position });
                }
                if (b.Carried <= 0 || Vec.Distance(b.Position, Safes[b.Team]) > 1.5f) continue;
                int n = b.Carried; b.Carried = 0; Score(world, b.Team, n);
                world.Emit(new SimEvent { Kind = EventKind.Deposit, Actor = b.Id, Amount = n });
            }
        }
        public void OnKill(World w, Brawler victim, Brawler killer)
        {
            if (Phase != MatchPhase.Playing) return;
            if (!Heist) { if (killer != null && killer.Team != victim.Team) Score(w, killer.Team, 1); return; }
            for (int i = 0; i < victim.Carried; i++)
                Shards.Add(w.Map.Resolve(victim.Position + new Vec(0.5f, 0).Rotated((float)Math.PI * 2 * i / victim.Carried), 0.2f));
            victim.Carried = 0;
        }
        void Score(World w, int team, int amount)
        {
            if (Phase != MatchPhase.Playing) return;
            Scores[team] += amount; w.Emit(new SimEvent { Kind = EventKind.Score, Actor = team, Amount = Scores[team] });
            if (Scores[team] >= Target) Finish(w, team);
        }
        void Finish(World w, int winner)
        { Phase = MatchPhase.Finished; Winner = winner; w.Emit(new SimEvent { Kind = EventKind.MatchEnd, Actor = winner }); }
        public bool Objective(Brawler b, out Vec goal, out bool urgent)
        {
            goal = Mine; urgent = false; if (!Heist) return false;
            if (b.Carried >= 2 || b.Carried > 0 && b.Hp < b.Data.max_hp * 0.5f) { goal = Safes[b.Team]; urgent = true; return true; }
            float best = float.MaxValue;
            foreach (var s in Shards) { float d = Vec.Distance(b.Position, s); if (d < best) { best = d; goal = s; } }
            if (best < float.MaxValue) urgent = best < 4;
            else if (b.Carried > 0) goal = Safes[b.Team];
            return true;
        }
    }
}
