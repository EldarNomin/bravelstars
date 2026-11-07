using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Bravel.Sim;

namespace Bravel
{
    public sealed class ArenaView : MonoBehaviour
    {
        public readonly Transform[] Heroes = new Transform[6];
        readonly Animation[] animationPlayers = new Animation[6];
        readonly string[] locomotion = new string[6];
        readonly float[] actionUntil = new float[6];
        readonly GameObject[] projectileViews = new GameObject[World.ProjectileCapacity];
        readonly MeshFilter[] projectileFilters = new MeshFilter[World.ProjectileCapacity];
        readonly Renderer[] projectileRenderers = new Renderer[World.ProjectileCapacity];
        readonly Mesh[] projectileMeshes = new Mesh[4];
        readonly Dictionary<int, int> projectileSlots = new Dictionary<int, int>(World.ProjectileCapacity);
        readonly int[] slotIds = new int[World.ProjectileCapacity];
        readonly bool[] used = new bool[World.ProjectileCapacity];
        readonly GameObject[] shardViews = new GameObject[64];
        readonly List<Material> ownedMaterials = new List<Material>();
        readonly List<Mesh> ownedMeshes = new List<Mesh>();
        readonly List<GameObject> dynamicTiles = new List<GameObject>();
        readonly List<int> tileCells = new List<int>();
        readonly List<Tile> originalTiles = new List<Tile>();
        LineRenderer aimLine, targetCircle;
        Material blue, red, gold, ground;
        int mapVersion = -1;
        public void Initialize(Match match)
        {
            blue = Material(GameUi.Blue); red = Material(GameUi.Red); gold = Material(GameUi.Gold); ground = Material(new Color32(125, 107, 88, 255));
            var mapRoot = new GameObject("Arena geometry").transform; mapRoot.SetParent(transform, false); var map = match.World.Map;
            var floor = GameObject.CreatePrimitive(PrimitiveType.Cube); floor.name = "Ground"; floor.transform.SetParent(mapRoot, false);
            floor.transform.position = new Vector3(map.Width * 0.5f, -0.16f, map.Height * 0.5f); floor.transform.localScale = new Vector3(map.Width + 40, 0.2f, map.Height + 40);
            floor.GetComponent<Renderer>().sharedMaterial = ground; Destroy(floor.GetComponent<Collider>());
            var models = new GameObject[5];
            models[(int)Tile.Wall] = RequireModel("env/wall"); models[(int)Tile.HardWall] = RequireModel("env/hard_wall");
            models[(int)Tile.Bush] = RequireModel("env/bush_01"); models[(int)Tile.Water] = RequireModel("env/water");
            for (int i = 0; i < map.Tiles.Length; i++)
            {
                var tile = map.Tiles[i]; if (tile == Tile.Floor) continue;
                var piece = Instantiate(models[(int)tile], mapRoot); piece.name = "Tile " + i; piece.transform.localPosition = Position(map.Center(i));
                if (tile == Tile.Wall || tile == Tile.Bush) { dynamicTiles.Add(piece); tileCells.Add(i); originalTiles.Add(tile); }
            }
            var sourceMeshes = new HashSet<Mesh>();
            foreach (var filter in mapRoot.GetComponentsInChildren<MeshFilter>()) sourceMeshes.Add(filter.sharedMesh);
            StaticBatchingUtility.Combine(mapRoot.gameObject);
            foreach (var filter in mapRoot.GetComponentsInChildren<MeshFilter>())
                if (!sourceMeshes.Contains(filter.sharedMesh) && !ownedMeshes.Contains(filter.sharedMesh)) ownedMeshes.Add(filter.sharedMesh);
            for (int i = 0; i < match.World.Brawlers.Count; i++)
            {
                var b = match.World.Brawlers[i]; var root = new GameObject("Hero " + b.Data.id + " team " + b.Team).transform; root.SetParent(transform, false);
                Heroes[i] = root; var model = Instantiate(RequireModel("heroes/" + b.Data.id), root); model.name = "Model";
                model.transform.localRotation = Quaternion.Euler(0, 180, 0);
                model.transform.localScale = Vector3.one * 1.35f;
                var anim = model.GetComponent<Animation>(); animationPlayers[i] = anim;
                if (anim == null) throw new InvalidOperationException("Missing legacy animation on " + b.Data.id);
                foreach (string name in new[] { "idle", "run", "attack", "super", "death" })
                    if (anim.GetClip(name) == null) throw new InvalidOperationException("Missing clip " + b.Data.id + "/" + name);
                anim.Play("idle"); locomotion[i] = "idle";
                var marker = new GameObject(b.Team == 0 ? "Circle team marker" : "Triangle team marker", typeof(MeshFilter), typeof(MeshRenderer)); marker.transform.SetParent(root, false); marker.transform.localPosition = Vector3.up * 0.04f;
                var mesh = MarkerMesh(b.Team == 0 ? 32 : 3); ownedMeshes.Add(mesh); marker.GetComponent<MeshFilter>().sharedMesh = mesh; marker.GetComponent<Renderer>().sharedMaterial = b.Team == 0 ? blue : red;
                root.position = Position(b.Position);
            }
            var projectileMesh = new GameObject("Projectile pool").transform; projectileMesh.SetParent(transform, false);
            string[] names = { "lynx_bullet", "anvil_pellet", "pinecone", "pinecone_super" };
            for (int i = 0; i < names.Length; i++) projectileMeshes[i] = RequireModel("fx/" + names[i]).GetComponentInChildren<MeshFilter>().sharedMesh;
            var bullet = RequireModel("fx/lynx_bullet");
            for (int i = 0; i < projectileViews.Length; i++)
            {
                var go = Instantiate(bullet, projectileMesh); projectileViews[i] = go;
                projectileFilters[i] = go.GetComponentInChildren<MeshFilter>(); projectileRenderers[i] = go.GetComponentInChildren<Renderer>(); go.SetActive(false);
            }
            for (int i = 0; i < shardViews.Length; i++) { shardViews[i] = Instantiate(RequireModel("fx/loot_shard"), transform); shardViews[i].SetActive(false); }
            if (match.World.Mode.Heist)
            {
                var mode = match.World.Mode;
                Instantiate(RequireModel("fx/mine"), Position(mode.Mine), Quaternion.identity, transform);
                for (int t = 0; t < 2; t++)
                {
                    Instantiate(RequireModel(t == 0 ? "fx/safe_blue" : "fx/safe_red"), Position(mode.Safes[t]), Quaternion.identity, transform);
                    var zone = Line("Delivery zone " + t, 33); zone.sharedMaterial = t == 0 ? blue : red; zone.enabled = true;
                    for (int i = 0; i < 33; i++) zone.SetPosition(i, Position(mode.Safes[t], 0.08f) + new Vector3(Mathf.Cos(i * Mathf.PI / 16), 0, Mathf.Sin(i * Mathf.PI / 16)) * 1.5f);
                }
            }
            aimLine = Line("Aim direction", 2); targetCircle = Line("Lob target", 33);
        }
        public static Vector3 Position(Vec p, float height = 0) => new Vector3(p.X, height, p.Y);
        static GameObject RequireModel(string path)
        { var model = Resources.Load<GameObject>("Models/" + path); if (model == null) throw new InvalidOperationException("Missing model: " + path); return model; }
        Material Material(Color color)
        { var material = new Material(Shader.Find("Bravel/Mobile Palette")); material.color = color; material.enableInstancing = true; ownedMaterials.Add(material); return material; }
        LineRenderer Line(string name, int points)
        {
            var go = new GameObject(name); go.transform.SetParent(transform, false); var line = go.AddComponent<LineRenderer>();
            line.sharedMaterial = gold; line.positionCount = points; line.widthMultiplier = 0.075f; line.shadowCastingMode = ShadowCastingMode.Off; line.receiveShadows = false; line.enabled = false; return line;
        }
        static Mesh MarkerMesh(int sides)
        {
            var vertices = new Vector3[sides + 1]; var triangles = new int[sides * 3];
            for (int i = 0; i < sides; i++)
            {
                float a = i * Mathf.PI * 2 / sides; vertices[i + 1] = new Vector3(Mathf.Sin(a) * 0.61f, 0, Mathf.Cos(a) * 0.61f);
                triangles[i * 3] = 0; triangles[i * 3 + 1] = i + 1; triangles[i * 3 + 2] = (i + 1) % sides + 1;
            }
            var mesh = new Mesh { name = "Team marker", vertices = vertices, triangles = triangles }; mesh.RecalculateNormals(); return mesh;
        }
        public void Render(Match match, float alpha, Vector2 aim, bool aiming, bool super)
        {
            var world = match.World;
            if (mapVersion != world.Map.Version)
            {
                mapVersion = world.Map.Version;
                for (int i = 0; i < dynamicTiles.Count; i++) dynamicTiles[i].SetActive(world.Map.Tiles[tileCells[i]] == originalTiles[i]);
            }
            for (int i = 0; i < world.Brawlers.Count; i++)
            {
                var b = world.Brawlers[i]; var root = Heroes[i]; bool visible = world.Visible(0, b);
                if (root.gameObject.activeSelf != visible) root.gameObject.SetActive(visible);
                if (!visible) continue;
                root.position = Position(Vec.Lerp(b.Previous, b.Position, alpha));
                if (b.Facing.LengthSquared > 0.0001f) root.rotation = Quaternion.Slerp(root.rotation, Quaternion.LookRotation(Position(b.Facing)), 1 - Mathf.Exp(-18 * Time.unscaledDeltaTime));
                string next = Vec.Distance(b.Previous, b.Position) > 0.001f ? "run" : "idle";
                if (Time.unscaledTime >= actionUntil[i] && (next != locomotion[i] || !animationPlayers[i].isPlaying))
                { animationPlayers[i].CrossFade(next, 0.08f); locomotion[i] = next; }
            }
            Array.Clear(used, 0, used.Length);
            foreach (var p in world.Projectiles)
            {
                if (!projectileSlots.TryGetValue(p.Id, out int slot))
                {
                    slot = -1; for (int i = 0; i < slotIds.Length; i++) if (slotIds[i] == 0) { slot = i; break; }
                    if (slot < 0) continue;
                    slotIds[slot] = p.Id; projectileSlots[p.Id] = slot; projectileViews[slot].SetActive(true);
                    projectileRenderers[slot].sharedMaterial = p.Super ? gold : p.Owner.Team == 0 ? blue : red;
                    projectileFilters[slot].sharedMesh = projectileMeshes[p.Data.kind == 1 ? p.Super ? 3 : 2 : p.Owner.Data.id == "anvil" ? 1 : 0];
                }
                used[slot] = true; var go = projectileViews[slot]; float height = p.Data.kind == 1 ? 0.4f + Mathf.Sin(p.Progress * Mathf.PI) * 2.6f : 0.55f;
                go.transform.position = Position(Vec.Lerp(p.Previous, p.Position, alpha), height);
                go.transform.rotation = Quaternion.LookRotation(Position(-p.Direction)); go.transform.localScale = Vector3.one * (p.Super ? 2 : p.Data.kind == 1 ? 1.5f : 1);
            }
            for (int i = 0; i < slotIds.Length; i++) if (slotIds[i] != 0 && !used[i])
            { projectileSlots.Remove(slotIds[i]); slotIds[i] = 0; projectileViews[i].SetActive(false); }
            for (int i = 0; i < shardViews.Length; i++)
            {
                bool active = i < world.Mode.Shards.Count; if (shardViews[i].activeSelf != active) shardViews[i].SetActive(active);
                if (active) { shardViews[i].transform.position = Position(world.Mode.Shards[i], 0.3f); shardViews[i].transform.rotation = Quaternion.Euler(0, Time.unscaledTime * 90, 0); }
            }
            aimLine.enabled = targetCircle.enabled = aiming && match.Player.Alive;
            if (!aiming || !match.Player.Alive) return;
            var attack = super ? match.Player.Data.super_attack : match.Player.Data.attack; var vector = new Vec(aim.x, aim.y);
            Vec dir = vector.LengthSquared < 0.001f ? match.Player.Facing : vector.Normalized;
            float range = attack.kind == 1 ? Vec.Clamp(vector.Length * attack.range_tiles, attack.min_range_tiles, attack.range_tiles) : attack.range_tiles;
            Vector3 from = Heroes[match.Player.Index].position + Vector3.up * 0.1f, to = from + Position(dir * range);
            aimLine.SetPosition(0, from); aimLine.SetPosition(1, to);
            targetCircle.enabled = attack.kind == 1;
            if (targetCircle.enabled) for (int i = 0; i < 33; i++) { float angle = i * Mathf.PI * 2 / 32; targetCircle.SetPosition(i, to + new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * attack.area_radius); }
        }
        public void Event(SimEvent e, World world)
        {
            if (e.Kind != EventKind.Attack && e.Kind != EventKind.Super) return;
            for (int i = 0; i < world.Brawlers.Count; i++) if (world.Brawlers[i].Id == e.Actor)
            {
                string action = e.Super || e.Kind == EventKind.Super ? "super" : "attack";
                animationPlayers[i].CrossFade(action, 0.04f); actionUntil[i] = Time.unscaledTime + animationPlayers[i].GetClip(action).length;
            }
        }
        void OnDestroy()
        {
            foreach (var m in ownedMaterials) if (m != null) Destroy(m);
            foreach (var m in ownedMeshes) if (m != null) Destroy(m);
        }
    }
}
