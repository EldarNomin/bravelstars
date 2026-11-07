using System;
using System.Collections.Generic;

namespace Bravel.Sim
{
    public sealed class Pathfinder
    {
        readonly ArenaMap map;
        readonly int[] queue, parent, visited;
        int search;
        public Pathfinder(ArenaMap map)
        { this.map = map; queue = new int[map.Tiles.Length]; parent = new int[queue.Length]; visited = new int[queue.Length]; }
        public void Find(Vec from, Vec to, List<Vec> path)
        {
            path.Clear(); int sx = (int)from.X, sy = (int)from.Y;
            int gx = (int)Vec.Clamp(to.X, 0, map.Width - 1), gy = (int)Vec.Clamp(to.Y, 0, map.Height - 1);
            if (!map.Walkable(gx, gy))
            {
                bool found = false;
                for (int r = 1; r <= 3 && !found; r++) for (int dy = -r; dy <= r && !found; dy++) for (int dx = -r; dx <= r; dx++)
                    if (map.Walkable(gx + dx, gy + dy)) { gx += dx; gy += dy; found = true; break; }
                if (!found) return;
            }
            if (!map.Walkable(sx, sy)) return;
            int start = sy * map.Width + sx, goal = gy * map.Width + gx, head = 0, tail = 0;
            search++; queue[tail++] = start; visited[start] = search; parent[start] = -1;
            while (head < tail && visited[goal] != search)
            {
                int c = queue[head++], x = c % map.Width, y = c / map.Width;
                for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
                {
                    if (dx == 0 && dy == 0 || !map.Walkable(x + dx, y + dy)) continue;
                    if (dx != 0 && dy != 0 && (!map.Walkable(x + dx, y) || !map.Walkable(x, y + dy))) continue;
                    int n = (y + dy) * map.Width + x + dx; if (visited[n] == search) continue;
                    visited[n] = search; parent[n] = c; queue[tail++] = n;
                }
            }
            if (visited[goal] != search) return;
            for (int c = goal; c != start; c = parent[c]) path.Add(map.Center(c));
            path.Reverse();
        }
    }

    public sealed class Bot
    {
        enum State { Roam, Fight, Chase, Retreat }
        readonly Brawler me;
        readonly BotProfile profile;
        readonly Pathfinder nav;
        readonly SeededRandom rng;
        readonly Vec[] memory = new Vec[16], velocity = new Vec[16];
        readonly int[] seen = new int[16];
        readonly List<Vec> path = new List<Vec>(128);
        State state;
        int nextThink, targetIndex = -1, repathAt, pathIndex, repositionUntil, mapVersion = -1;
        Vec roam, pathGoal;
        float strafeSign = 1;
        bool hasRoam;
        public Bot(Brawler b, Pathfinder nav, int difficulty, int seed)
        {
            me = b; this.nav = nav; profile = b.Data.bot.Tuned(difficulty); rng = new SeededRandom(seed * 7919 + b.Id);
            for (int i = 0; i < seen.Length; i++) seen[i] = -100000;
        }
        public void Drive(World w) { w.Input(me, Think(w)); }
        public Command Think(World w)
        {
            if (!me.Alive) { path.Clear(); return default; }
            Brawler target = null; float best = float.MaxValue;
            foreach (var e in w.Brawlers)
            {
                if (e.Team == me.Team) continue;
                int i = e.Index;
                if (!e.Alive) { seen[i] = -100000; continue; }
                if (w.Visible(me.Team, e))
                { velocity[i] = w.Tick - seen[i] == 1 ? (e.Position - memory[i]) * World.TickRate : default; memory[i] = e.Position; seen[i] = w.Tick; }
                if (w.Tick - seen[i] > World.Seconds(profile.memory_time)) continue;
                float score = Vec.Distance(me.Position, memory[i]) + 3f * e.Hp / e.Data.max_hp + (seen[i] == w.Tick ? 0 : 4) - (targetIndex == i ? 1.5f : 0);
                if (score < best) { best = score; target = e; }
            }
            targetIndex = target?.Index ?? -1;
            if (w.Tick >= nextThink)
            {
                nextThink = w.Tick + profile.reaction_ticks;
                state = target == null ? State.Roam : me.Hp < me.Data.max_hp * profile.retreat_hp ? State.Retreat : seen[target.Index] == w.Tick ? State.Fight : State.Chase;
                if (!hasRoam || Vec.Distance(me.Position, roam) < 1)
                {
                    Vec center = new Vec(w.Map.Width * 0.5f, w.Map.Height * 0.5f);
                    for (int n = 0; n < 10; n++)
                    {
                        var p = center + new Vec(rng.Range(-4, 4), rng.Range(-4, 4));
                        if (!ArenaMap.BlocksMovement(w.Map.At(p))) { roam = p; hasRoam = true; break; }
                    }
                }
                if (w.Tick % 25 == 0 && rng.Next() < 0.5f) strafeSign = -strafeSign;
            }
            var cmd = new Command();
            Vec goal = roam; bool urgent = false;
            bool objective = w.Mode != null && w.Mode.Objective(me, out goal, out urgent);
            if (objective && (urgent || target == null) && state != State.Retreat) cmd.Move = Follow(w, goal);
            else if (target == null) cmd.Move = Follow(w, roam);
            else if (state == State.Retreat)
            {
                var away = (me.Position - memory[target.Index]).Normalized;
                Vec retreat = me.Spawn; float max = float.MinValue;
                for (int i = 0; i < 8; i++)
                {
                    var p = me.Position + away.Rotated((i - 3.5f) * 0.35f) * 4;
                    if (ArenaMap.BlocksMovement(w.Map.At(p))) continue;
                    float s = Vec.Distance(p, memory[target.Index]) + (w.Map.At(p) == Tile.Bush ? 4 * profile.bush_preference : 0);
                    if (s > max) { max = s; retreat = p; }
                }
                cmd.Move = Follow(w, retreat);
            }
            else if (seen[target.Index] != w.Tick) cmd.Move = Follow(w, memory[target.Index]);
            else
            {
                var to = target.Position - me.Position; float want = me.Data.attack.range_tiles * profile.preferred_range;
                if (!CanHit(w, target, me.Data.attack)) repositionUntil = w.Tick + 15;
                if (to.Length > want || w.Tick < repositionUntil) cmd.Move = Follow(w, target.Position);
                else
                {
                    Vec dir = to.Normalized, strafe = new Vec(-dir.Y, dir.X) * strafeSign;
                    cmd.Move = (strafe * 0.8f + (to.Length < want * 0.6f ? -dir : default)).Limited();
                    if (ArenaMap.BlocksMovement(w.Map.At(me.Position + cmd.Move * 0.7f))) { strafeSign = -strafeSign; cmd.Move = -cmd.Move; }
                }
            }
            if (target == null || seen[target.Index] != w.Tick) return cmd;
            var atk = me.Data.attack; float dist = Vec.Distance(me.Position, target.Position);
            if (me.Ammo > 0 && me.Cooldown == 0 && dist <= atk.range_tiles + target.Data.radius * 0.5f && CanHit(w, target, atk)
                && (state != State.Retreat || dist < atk.range_tiles * 0.6f) && rng.Next() <= profile.trigger_discipline)
            { cmd.Attack = true; cmd.Aim = Aim(target, atk); }
            var sup = me.Data.super_attack;
            if (me.SuperReady && sup != null && dist <= sup.range_tiles + (me.Data.super_ability == "dash" ? 1.5f : 0) && CanHit(w, target, sup))
            { cmd.Super = true; cmd.SuperAim = Aim(target, sup); }
            return cmd;
        }
        bool CanHit(World w, Brawler target, AttackData a) => a.kind == 1 || a.breaks_walls || w.Map.Line(me.Position, target.Position, a.projectile_radius + 0.1f);
        Vec Aim(Brawler target, AttackData a)
        {
            var to = target.Position - me.Position; float travel = a.kind == 1 ? a.flight_time : to.Length / Math.Max(0.1f, a.speed);
            return (to + velocity[target.Index] * (travel * profile.skill)).Rotated(rng.Range(-1, 1) * profile.aim_error_deg * (1 - profile.skill) * (float)Math.PI / 180);
        }
        Vec Follow(World w, Vec goal)
        {
            if (w.Map.Line(me.Position, goal, me.Data.radius + 0.02f, true))
            { path.Clear(); return Vec.Distance(me.Position, goal) > 0.2f ? (goal - me.Position).Normalized : default; }
            if (pathIndex >= path.Count || w.Tick >= repathAt || mapVersion != w.Map.Version || Vec.Distance(goal, pathGoal) > 1.5f)
            { nav.Find(me.Position, goal, path); pathIndex = 0; pathGoal = goal; repathAt = w.Tick + 10; mapVersion = w.Map.Version; }
            while (pathIndex < path.Count && Vec.Distance(me.Position, path[pathIndex]) < 0.35f) pathIndex++;
            return pathIndex >= path.Count ? default : (path[pathIndex] - me.Position).Normalized;
        }
    }

    public sealed class Match
    {
        public readonly World World;
        public readonly Brawler Player;
        public readonly Bot[] Bots;
        public Match(MapData map, HeroData[] heroes, Balance balance, int selected, int difficulty, int seed, bool allBots = false)
        {
            if (heroes == null || heroes.Length != 3 || selected < 0 || selected >= 3) throw new ArgumentException("Three heroes and valid selection required");
            World = new World(new ArenaMap(map), seed, balance); World.Mode = new MatchMode(World.Map, map.mode == "heist");
            var nav = new Pathfinder(World.Map); var bots = new List<Bot>(6);
            Player = World.Add(heroes[selected], 0);
            if (allBots) bots.Add(new Bot(Player, nav, difficulty, seed));
            for (int i = 0; i < 3; i++) if (i != selected) bots.Add(new Bot(World.Add(heroes[i], 0), nav, difficulty, seed));
            for (int i = 0; i < 3; i++) bots.Add(new Bot(World.Add(heroes[i], 1), nav, difficulty, seed));
            Bots = bots.ToArray();
        }
        public void Step(Command input)
        {
            World.Input(Player, input);
            foreach (var bot in Bots) bot.Drive(World);
            World.Step();
        }
    }
}
