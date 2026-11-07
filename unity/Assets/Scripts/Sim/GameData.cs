using System;

namespace Bravel.Sim
{
    [Serializable]
    public sealed class AttackData
    {
        public int kind, damage = 500, projectile_count = 1, super_charge_per_hit = 250;
        public float spread_deg, range_tiles = 7, min_range_tiles, speed = 12, projectile_radius = 0.2f;
        public bool pierce, breaks_walls;
        public float area_radius = 1, flight_time = 0.8f, knockback, stun_time;
    }

    [Serializable]
    public sealed class HeroData
    {
        public string id, display_name, description, super_ability;
        public int max_hp = 3200, max_ammo = 3;
        public float move_speed = 2.4f, radius = 0.4f, reload_time = 1.4f, attack_cooldown = 0.4f;
        public AttackData attack, super_attack;
        public BotProfile bot = new BotProfile();
    }

    [Serializable]
    public sealed class Balance
    {
        public float regen_delay = 3, regen_percent_per_sec = 0.13f, respawn_time = 4, spawn_shield_time = 2;
        public bool keep_super_on_death = true;
        public float bush_reveal_distance = 2, reveal_after_attack = 1.5f, reveal_after_hit = 1;
        public float bush_regrow_time = 12, knockback_duration = 0.15f;
    }

    [Serializable]
    public sealed class BotProfile
    {
        public float skill = 0.5f, preferred_range = 0.75f, retreat_hp = 0.35f, bush_preference = 0.6f;
        public int reaction_ticks = 6;
        public float memory_time = 2.5f, aim_error_deg = 14, trigger_discipline = 1;
        public BotProfile Tuned(int difficulty)
        {
            var p = (BotProfile)MemberwiseClone();
            p.skill = Vec.Clamp(skill * (difficulty == 0 ? 0.5f : difficulty == 2 ? 1.3f : 1), 0.05f, 1);
            p.reaction_ticks = Math.Max(2, World.Seconds(reaction_ticks / 30f * (difficulty == 0 ? 1.8f : difficulty == 2 ? 0.6f : 1)));
            p.aim_error_deg = difficulty == 0 ? 30 : difficulty == 2 ? 6 : 14;
            p.trigger_discipline = difficulty == 0 ? 0.15f : difficulty == 2 ? 1 : 0.6f;
            return p;
        }
    }

    public struct Command
    {
        public Vec Move, Aim, SuperAim;
        public bool Attack, Super;
    }

    public enum EventKind { Attack, Super, Hit, Death, Respawn, TileDestroyed, TileRestored, Explosion, MatchStart, MatchEnd, Score, Pickup, Deposit }
    public struct SimEvent
    {
        public EventKind Kind;
        public int Tick, Actor, Target, Amount, AttackId, Cell;
        public Vec Position;
        public bool Super;
    }
}
