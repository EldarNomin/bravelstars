using System;

namespace Bravel.Sim
{
    [Serializable]
    public struct Vec
    {
        public float X, Y;
        public Vec(float x, float y) { X = x; Y = y; }
        public float LengthSquared => X * X + Y * Y;
        public float Length => (float)Math.Sqrt(LengthSquared);
        public Vec Normalized => Length > 0.0001f ? this / Length : default;
        public Vec Limited(float n = 1) => LengthSquared > n * n ? Normalized * n : this;
        public Vec Rotated(float radians) => new Vec(X * (float)Math.Cos(radians) - Y * (float)Math.Sin(radians), X * (float)Math.Sin(radians) + Y * (float)Math.Cos(radians));
        public static Vec operator +(Vec a, Vec b) => new Vec(a.X + b.X, a.Y + b.Y);
        public static Vec operator -(Vec a, Vec b) => new Vec(a.X - b.X, a.Y - b.Y);
        public static Vec operator -(Vec a) => new Vec(-a.X, -a.Y);
        public static Vec operator *(Vec a, float k) => new Vec(a.X * k, a.Y * k);
        public static Vec operator /(Vec a, float k) => new Vec(a.X / k, a.Y / k);
        public static float Dot(Vec a, Vec b) => a.X * b.X + a.Y * b.Y;
        public static float Distance(Vec a, Vec b) => (a - b).Length;
        public static Vec Lerp(Vec a, Vec b, float t) => a + (b - a) * t;
        public static float Clamp(float x, float min, float max) => Math.Max(min, Math.Min(max, x));
        public static Vec Closest(Vec p, Vec a, Vec b) => Lerp(a, b, Clamp(Dot(p - a, b - a) / Math.Max(0.000001f, (b - a).LengthSquared), 0, 1));
    }

    public sealed class SeededRandom
    {
        uint state;
        public SeededRandom(int seed) { state = (uint)seed; if (state == 0) state = 1; }
        public float Next() { state ^= state << 13; state ^= state >> 17; state ^= state << 5; return (state >> 8) / 16777216f; }
        public float Range(float min, float max) => min + Next() * (max - min);
    }
}
