using System;
using System.Collections.Generic;

namespace Bravel.Sim
{
    public sealed class Brawler
    {
        public readonly int Id, Index, Team;
        public readonly HeroData Data;
        public readonly Vec Spawn;
        public Vec Position, Previous, Facing = new Vec(1, 0), KnockStep, DashDirection;
        public int Hp, Ammo, Reload, Cooldown, SuperCharge, Stun, RespawnAt = -1, ShieldUntil = -1;
        public int KnockTicks, RegenMilli, Kills, Deaths, Carried, DashTicks, DashHits;
        public int LastDamage = -100000, LastAttack = -100000, RevealUntil = -1;
        public bool Alive = true;
        public Brawler(int id, int index, int team, HeroData data, Vec at)
        { Id = id; Index = index; Team = team; Data = data; Spawn = at; Reset(); }
        public void Reset()
        {
            Position = Previous = Spawn; Hp = Data.max_hp; Ammo = Data.max_ammo; Alive = true;
            Reload = Cooldown = Stun = KnockTicks = RegenMilli = DashTicks = DashHits = 0; RespawnAt = -1;
        }
        public bool SuperReady => SuperCharge >= 1000;
    }

    public sealed class Projectile
    {
        public int Id, AttackId, Age, FlightTicks, HitMask;
        public Brawler Owner;
        public AttackData Data;
        public Vec Position, Previous, Start, Target, Direction;
        public bool Super, Dead;
        public float Traveled;
        public float Progress => FlightTicks <= 0 ? 1 : Vec.Clamp((float)Age / FlightTicks, 0, 1);
    }

    public sealed class World
    {
        public const int TickRate = 30, ProjectileCapacity = 256;
        public const float Dt = 1f / TickRate;
        public static int Seconds(float seconds) => (int)Math.Round(seconds * TickRate, MidpointRounding.AwayFromZero);
        public int Tick { get; private set; }
        public readonly ArenaMap Map;
        public readonly Balance Balance;
        public readonly SeededRandom Rng;
        public readonly List<Brawler> Brawlers = new List<Brawler>(6);
        public readonly List<Projectile> Projectiles = new List<Projectile>(ProjectileCapacity);
        public readonly List<SimEvent> Events = new List<SimEvent>(256);
        public MatchMode Mode;
        public bool RespawnEnabled = true;
        readonly Command[] inputs = new Command[16];
        readonly Stack<Projectile> pool = new Stack<Projectile>(ProjectileCapacity);
        readonly int[] regrow;
        int nextId = 1;
        public World(ArenaMap map, int seed, Balance balance)
        {
            Map = map ?? throw new ArgumentNullException(nameof(map)); Balance = balance ?? new Balance(); Rng = new SeededRandom(seed);
            regrow = new int[map.Tiles.Length];
            for (int i = 0; i < ProjectileCapacity; i++) pool.Push(new Projectile());
        }
        public Brawler Add(HeroData data, int team, Vec? at = null)
        {
            if (data?.attack == null || data.max_hp <= 0 || data.max_ammo <= 0 || data.reload_time <= 0 || team < 0 || team > 1 || Brawlers.Count >= inputs.Length)
                throw new ArgumentException("Invalid hero, team or world capacity");
            int count = 0; foreach (var b in Brawlers) if (b.Team == team) count++;
            var points = Map.Spawns[team];
            int index = points.Count == 0 ? 0 : count % points.Count;
            if (team == 1) index = points.Count - 1 - index;
            Vec spawn = at ?? (points.Count > 0 ? points[index] : new Vec(Map.Width * 0.5f, Map.Height * 0.5f));
            var hero = new Brawler(nextId++, Brawlers.Count, team, data, spawn); Brawlers.Add(hero); return hero;
        }
        public void Input(Brawler b, Command command) { inputs[b.Index] = command; }
        public void Emit(SimEvent e)
        {
            if (Events.Count >= 2048) throw new InvalidOperationException("Drain simulation events between frames");
            e.Tick = Tick; Events.Add(e);
        }
        public void DrainEvents(List<SimEvent> output) { output.AddRange(Events); Events.Clear(); }
        public void Step()
        {
            if (Mode != null && Mode.Phase == MatchPhase.Finished) { Array.Clear(inputs, 0, inputs.Length); return; }
            foreach (var b in Brawlers)
            {
                b.Previous = b.Position;
                Apply(b, Mode == null || Mode.Phase == MatchPhase.Playing ? inputs[b.Index] : default);
            }
            foreach (var b in Brawlers) if (b.Alive) UpdateDash(b);
            UpdateProjectiles();
            foreach (var b in Brawlers) Timers(b);
            for (int i = 0; i < regrow.Length; i++) if (regrow[i] > 0 && Tick >= regrow[i])
            {
                regrow[i] = 0;
                if (Map.Tiles[i] != Tile.Floor) continue;
                Map.Set(i, Tile.Bush); Emit(new SimEvent { Kind = EventKind.TileRestored, Cell = i });
            }
            Mode?.Step(this); Array.Clear(inputs, 0, inputs.Length); Tick++;
        }
        void Apply(Brawler b, Command cmd)
        {
            if (!b.Alive) return;
            if (b.KnockTicks > 0) { b.KnockTicks--; Move(b, b.KnockStep); }
            if (b.Stun > 0 || b.DashTicks > 0) return;
            var mv = cmd.Move.Limited();
            if (mv.LengthSquared > 0.0001f && b.KnockTicks == 0)
            { Move(b, mv * b.Data.move_speed * (b.Carried > 0 ? 0.85f : 1) * Dt); b.Facing = mv.Normalized; }
            if (cmd.Attack && b.Ammo > 0 && b.Cooldown == 0)
            {
                b.Ammo--; b.Cooldown = Seconds(b.Data.attack_cooldown); b.LastAttack = Tick; b.ShieldUntil = -1;
                Fire(b, b.Data.attack, cmd.Aim, false);
            }
            if (!cmd.Super || !b.SuperReady || b.Data.super_attack == null) return;
            b.SuperCharge = 0; b.LastAttack = Tick; b.ShieldUntil = -1;
            b.RevealUntil = Tick + Seconds(Balance.reveal_after_attack);
            Emit(new SimEvent { Kind = EventKind.Super, Actor = b.Id, Position = b.Position });
            if (b.Data.super_ability == "dash")
            {
                Vec aim = cmd.SuperAim.LengthSquared > 0.0001f ? cmd.SuperAim : AutoAim(b, b.Data.super_attack.range_tiles + 1.5f);
                b.DashDirection = aim.LengthSquared > 0.0001f ? aim.Normalized : b.Facing;
                b.Facing = b.DashDirection; b.DashTicks = Seconds(0.3f); b.DashHits = 0;
            }
            else Fire(b, b.Data.super_attack, cmd.SuperAim, true);
        }
        public void Move(Brawler b, Vec delta)
        {
            int n = Math.Max(1, (int)Math.Ceiling(delta.Length / 0.25f));
            for (int i = 0; i < n; i++) b.Position = Map.Resolve(b.Position + delta / n, b.Data.radius);
        }
        void UpdateDash(Brawler b)
        {
            if (b.DashTicks <= 0) return;
            b.DashTicks--; var a = b.Data.super_attack; float step = a.range_tiles / Seconds(0.3f);
            if (a.breaks_walls)
            {
                var perp = new Vec(-b.DashDirection.Y, b.DashDirection.X);
                for (int i = -1; i <= 1; i++)
                    DestroyAt(b.Position + b.DashDirection * (b.Data.radius + step + 0.05f) + perp * (i * b.Data.radius));
            }
            Move(b, b.DashDirection * step);
            foreach (var e in Brawlers) if (e.Team != b.Team && e.Alive && (b.DashHits & (1 << e.Index)) == 0 && Vec.Distance(e.Position, b.Position) <= 0.9f)
            { b.DashHits |= 1 << e.Index; Damage(e, a.damage, b, a, true, b.Position); }
        }
        void Timers(Brawler b)
        {
            if (!b.Alive)
            {
                if (b.RespawnAt >= 0 && Tick >= b.RespawnAt)
                { b.Reset(); b.ShieldUntil = Tick + Seconds(Balance.spawn_shield_time); Emit(new SimEvent { Kind = EventKind.Respawn, Actor = b.Id, Position = b.Position }); }
                return;
            }
            if (b.Cooldown > 0) b.Cooldown--;
            if (b.Stun > 0) b.Stun--;
            if (b.Ammo < b.Data.max_ammo)
            {
                b.Reload++;
                if (b.Reload >= Seconds(b.Data.reload_time)) { b.Ammo++; b.Reload = 0; }
            }
            else b.Reload = 0;
            if (b.Hp < b.Data.max_hp && Tick - Math.Max(b.LastAttack, b.LastDamage) >= Seconds(Balance.regen_delay))
            {
                b.RegenMilli += (int)Math.Round(b.Data.max_hp * Balance.regen_percent_per_sec * 1000 / TickRate);
                int whole = b.RegenMilli / 1000; b.RegenMilli -= whole * 1000; b.Hp = Math.Min(b.Data.max_hp, b.Hp + whole);
            }
            else b.RegenMilli = 0;
        }
        public bool Visible(int team, Brawler b)
        {
            if (!b.Alive) return false;
            if (b.Team == team || b.Carried > 0 || Map.At(b.Position) != Tile.Bush || Tick < b.RevealUntil) return true;
            foreach (var e in Brawlers) if (e.Alive && e.Team == team && Vec.Distance(e.Position, b.Position) <= Balance.bush_reveal_distance) return true;
            return false;
        }
        public Vec AutoAim(Brawler caster, float range)
        {
            Brawler best = null; float dist = float.MaxValue;
            foreach (var e in Brawlers)
            {
                if (e.Team == caster.Team || !Visible(caster.Team, e)) continue;
                float d = Vec.Distance(e.Position, caster.Position);
                if (d <= range + e.Data.radius && d < dist) { best = e; dist = d; }
            }
            return best == null ? default : best.Position - caster.Position;
        }
        public void Fire(Brawler b, AttackData a, Vec aim, bool super)
        {
            if (aim.LengthSquared < 0.0001f) aim = AutoAim(b, a.range_tiles);
            var dir = aim.LengthSquared > 0.0001f ? aim.Normalized : b.Facing;
            b.Facing = dir; b.RevealUntil = Tick + Seconds(Balance.reveal_after_attack); int attackId = nextId++;
            int count = Math.Max(1, a.projectile_count);
            for (int i = 0; i < count; i++)
            {
                if (pool.Count == 0) throw new InvalidOperationException("Projectile capacity exhausted");
                var p = pool.Pop(); p.Id = nextId++; p.Owner = b; p.Data = a; p.Super = super; p.AttackId = attackId;
                p.Position = p.Previous = p.Start = b.Position; p.Direction = dir.Rotated(count > 1 ? (-a.spread_deg * 0.5f + a.spread_deg * i / (count - 1)) * (float)Math.PI / 180 : 0);
                p.Age = p.HitMask = 0; p.Traveled = 0; p.Dead = false; p.FlightTicks = a.kind == 1 ? Math.Max(1, Seconds(a.flight_time)) : 0;
                p.Target = b.Position + p.Direction * (aim.LengthSquared > 0.0001f ? Vec.Clamp(aim.Length, a.min_range_tiles, a.range_tiles) : a.range_tiles);
                Projectiles.Add(p);
            }
            Emit(new SimEvent { Kind = EventKind.Attack, Actor = b.Id, AttackId = attackId, Position = b.Position, Super = super });
        }
        void UpdateProjectiles()
        {
            for (int i = 0; i < Projectiles.Count; i++)
            {
                var p = Projectiles[i]; p.Previous = p.Position; p.Age++;
                if (p.Data.kind == 1) Lob(p); else Straight(p);
            }
            for (int i = Projectiles.Count - 1; i >= 0; i--) if (Projectiles[i].Dead)
            { var p = Projectiles[i]; Projectiles.RemoveAt(i); pool.Push(p); }
        }
        void Straight(Projectile p)
        {
            var a = p.Data; float remaining = Math.Min(a.speed * Dt, a.range_tiles - p.Traveled);
            int n = Math.Max(1, (int)Math.Ceiling(remaining / 0.2f)); float step = remaining / n;
            for (int i = 0; i < n; i++)
            {
                var prev = p.Position; p.Position += p.Direction * step; p.Traveled += step; var t = Map.At(p.Position);
                if (a.breaks_walls && (t == Tile.Wall || t == Tile.Bush)) DestroyAt(p.Position);
                else if (ArenaMap.BlocksShot(t)) { p.Dead = true; return; }
                foreach (var b in Brawlers)
                {
                    if (b.Team == p.Owner.Team || !b.Alive || (p.HitMask & (1 << b.Index)) != 0) continue;
                    if (Vec.Distance(Vec.Closest(b.Position, prev, p.Position), b.Position) > b.Data.radius + a.projectile_radius) continue;
                    p.HitMask |= 1 << b.Index; Damage(b, a.damage, p.Owner, a, p.Super, b.Position - p.Direction, p.AttackId);
                    if (!a.pierce) { p.Dead = true; return; }
                }
            }
            p.Dead = p.Traveled >= a.range_tiles - 0.0001f;
        }
        void Lob(Projectile p)
        {
            p.Position = Vec.Lerp(p.Start, p.Target, p.Progress); if (p.Age < p.FlightTicks) return;
            var a = p.Data;
            foreach (var b in Brawlers) if (b.Team != p.Owner.Team && b.Alive && Vec.Distance(b.Position, p.Target) <= a.area_radius + b.Data.radius)
                Damage(b, a.damage, p.Owner, a, p.Super, p.Target, p.AttackId);
            if (a.breaks_walls)
            {
                int r = (int)Math.Ceiling(a.area_radius), cx = (int)Math.Floor(p.Target.X), cy = (int)Math.Floor(p.Target.Y);
                for (int y = cy - r; y <= cy + r; y++) for (int x = cx - r; x <= cx + r; x++)
                    if (Vec.Distance(new Vec(x + 0.5f, y + 0.5f), p.Target) <= a.area_radius) DestroyAt(new Vec(x + 0.5f, y + 0.5f));
            }
            Emit(new SimEvent { Kind = EventKind.Explosion, Position = p.Target, Amount = (int)(a.area_radius * 100), Super = p.Super }); p.Dead = true;
        }
        public void DestroyAt(Vec at)
        {
            int x = (int)Math.Floor(at.X), y = (int)Math.Floor(at.Y); if (!Map.Inside(x, y)) return;
            int cell = y * Map.Width + x; var t = Map.Tiles[cell]; if (t != Tile.Wall && t != Tile.Bush) return;
            Map.Set(cell, Tile.Floor); Emit(new SimEvent { Kind = EventKind.TileDestroyed, Cell = cell, Position = at });
            if (t == Tile.Bush && Balance.bush_regrow_time > 0) regrow[cell] = Tick + Seconds(Balance.bush_regrow_time);
        }
        public void Damage(Brawler target, int amount, Brawler source, AttackData a, bool super, Vec from, int attackId = 0)
        {
            if (!target.Alive || Tick < target.ShieldUntil) return;
            target.Hp -= amount; target.LastDamage = Tick; target.RevealUntil = Math.Max(target.RevealUntil, Tick + Seconds(Balance.reveal_after_hit));
            if (source != null && source.Alive && a != null && !super) source.SuperCharge = Math.Min(1000, source.SuperCharge + a.super_charge_per_hit);
            Emit(new SimEvent { Kind = EventKind.Hit, Actor = source?.Id ?? 0, Target = target.Id, Amount = amount, AttackId = attackId, Position = target.Position, Super = super });
            if (target.Hp <= 0)
            {
                target.Alive = false; target.Hp = 0; target.Deaths++; target.DashTicks = target.DashHits = target.KnockTicks = 0;
                if (!Balance.keep_super_on_death) target.SuperCharge = 0;
                if (source != null && source != target) source.Kills++;
                if (RespawnEnabled) target.RespawnAt = Tick + Seconds(Balance.respawn_time);
                Emit(new SimEvent { Kind = EventKind.Death, Actor = source?.Id ?? 0, Target = target.Id, Position = target.Position });
                Mode?.OnKill(this, target, source); return;
            }
            if (a == null) return;
            if (a.knockback > 0)
            {
                var away = (target.Position - from).Normalized; if (away.LengthSquared < 0.0001f) away = new Vec(1, 0);
                target.KnockTicks = Math.Max(1, Seconds(Balance.knockback_duration)); target.KnockStep = away * (a.knockback / target.KnockTicks);
            }
            if (a.stun_time > 0) target.Stun = Math.Max(target.Stun, Seconds(a.stun_time) + 1);
        }
    }
}
