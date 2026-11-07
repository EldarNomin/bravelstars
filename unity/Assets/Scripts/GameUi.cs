using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Bravel.Sim;

namespace Bravel
{
    public sealed class GameUi : MonoBehaviour
    {
        public static readonly Color Background = new Color32(31, 36, 46, 255);
        public static readonly Color Panel = new Color32(40, 51, 65, 255);
        public static readonly Color Gold = new Color32(246, 173, 85, 255);
        public static readonly Color Blue = new Color32(43, 108, 176, 255), Red = new Color32(197, 48, 48, 255);
        public RectTransform SafeRoot { get; private set; }
        public TouchStick Movement, Attack, Super;
        public bool Paused { get; private set; }
        public Action<int, int, int> StartMatch;
        public Action LeaveMatch, InputReset, QualityChanged;
        public bool LowQuality { get; private set; }
        public float Sensitivity { get; private set; }
        Content content;
        Font font;
        Sprite disk;
        GameObject lobby, gameplay, overlay, settings;
        RectTransform overheadRoot;
        Text score, clock, playerStats, banner, superText;
        Image superRing;
        Button[] heroButtons, modeButtons, botButtons, mapButtons;
        readonly Text[] hpLabels = new Text[6];
        readonly Image[] hp = new Image[6];
        readonly Image[,] ammo = new Image[6, 3];
        readonly RectTransform[] overhead = new RectTransform[6];
        int selected, mode, difficulty = 1, map;
        string lastScore, lastClock, lastStats, lastBanner, lastSuper;
        public int SelectedHero => selected;
        public void Initialize(Content data)
        {
            content = data; selected = Mathf.Clamp(PlayerPrefs.GetInt("unity.hero", 0), 0, 2);
            LowQuality = PlayerPrefs.GetInt("unity.lowQuality", SystemInfo.systemMemorySize < 4096 ? 1 : 0) == 1;
            Sensitivity = Mathf.Clamp(PlayerPrefs.GetFloat("unity.sensitivity", 1), 0.5f, 1.5f);
            font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            disk = MakeDisk();
            var canvas = gameObject.AddComponent<Canvas>(); canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = gameObject.AddComponent<CanvasScaler>(); scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280, 720); scaler.matchWidthOrHeight = 1;
            gameObject.AddComponent<GraphicRaycaster>();
            SafeRoot = Rect("Safe area", transform, Vector2.zero, Vector2.one);
            var safe = SafeRoot.gameObject.AddComponent<SafeArea>(); safe.Changed = () => { ResetControls(); InputReset?.Invoke(); };
            if (EventSystem.current == null) new GameObject("Input events", typeof(EventSystem), typeof(StandaloneInputModule));
            BuildLobby(); BuildGameplay(); BuildSettings();
            ShowLobby();
        }
        public static RectTransform Rect(string name, Transform parent, Vector2 min, Vector2 max)
        {
            var go = new GameObject(name, typeof(RectTransform)); var r = (RectTransform)go.transform; r.SetParent(parent, false);
            r.anchorMin = min; r.anchorMax = max; r.offsetMin = r.offsetMax = Vector2.zero; return r;
        }
        public Image Box(string name, Transform parent, Vector2 min, Vector2 max, Color color, bool raycast = false)
        {
            var i = Rect(name, parent, min, max).gameObject.AddComponent<Image>(); i.color = color; i.raycastTarget = raycast; return i;
        }
        public Text Label(string name, Transform parent, Vector2 min, Vector2 max, string value, int size = 24, TextAnchor align = TextAnchor.MiddleCenter)
        {
            var t = Rect(name, parent, min, max).gameObject.AddComponent<Text>(); t.font = font; t.fontSize = size;
            t.color = Color.white; t.alignment = align; t.text = value; t.raycastTarget = false; t.supportRichText = false;
            t.horizontalOverflow = HorizontalWrapMode.Wrap; t.verticalOverflow = VerticalWrapMode.Truncate; return t;
        }
        Button Button(string name, Transform parent, Vector2 min, Vector2 max, string value, Action click, int size = 24)
        {
            var image = Box(name, parent, min, max, Panel, true); var button = image.gameObject.AddComponent<Button>(); button.targetGraphic = image;
            var colors = button.colors; colors.highlightedColor = new Color(1.18f, 1.18f, 1.18f); colors.pressedColor = new Color(0.7f, 0.7f, 0.7f); colors.selectedColor = Color.white; button.colors = colors;
            button.onClick.AddListener(() => click());
            Label("Label", image.transform, new Vector2(0.04f, 0.05f), new Vector2(0.96f, 0.95f), value, size); return button;
        }
        void BuildLobby()
        {
            lobby = Box("Lobby", SafeRoot, Vector2.zero, Vector2.one, Background, true).gameObject;
            var title = Label("Title", lobby.transform, new Vector2(0.04f, 0.86f), new Vector2(0.7f, 0.97f), "BRAVEL STARS", 36, TextAnchor.MiddleLeft); title.color = Gold;
            Button("Settings", lobby.transform, new Vector2(0.75f, 0.87f), new Vector2(0.96f, 0.97f), "Настройки", () => settings.SetActive(true), 22);
            heroButtons = new Button[3];
            string[] roles = { "СНАЙПЕР", "ТАНК", "МЕТАТЕЛЬ" };
            for (int i = 0; i < 3; i++)
            {
                int index = i; float x = 0.04f + i * 0.31f;
                var b = Button("Hero " + i, lobby.transform, new Vector2(x, 0.49f), new Vector2(x + 0.29f, 0.83f), "", () => { selected = index; UpdateSelection(); });
                heroButtons[i] = b; var hero = content.Heroes[i];
                Label("Role", b.transform, new Vector2(0.05f, 0.76f), new Vector2(0.95f, 0.94f), roles[i], 18).color = Gold;
                Label("Name", b.transform, new Vector2(0.05f, 0.55f), new Vector2(0.95f, 0.76f), hero.display_name, 28);
                Label("Health", b.transform, new Vector2(0.05f, 0.4f), new Vector2(0.95f, 0.54f), "HP " + hero.max_hp, 20);
                Label("Description", b.transform, new Vector2(0.06f, 0.02f), new Vector2(0.94f, 0.38f), hero.description, 18);
            }
            modeButtons = new Button[2]; botButtons = new Button[3]; mapButtons = new Button[2];
            Label("Mode heading", lobby.transform, new Vector2(0.04f, 0.42f), new Vector2(0.41f, 0.48f), "РЕЖИМ", 18, TextAnchor.MiddleLeft);
            Label("Bots heading", lobby.transform, new Vector2(0.51f, 0.42f), new Vector2(0.96f, 0.48f), "БОТЫ", 18, TextAnchor.MiddleLeft);
            for (int i = 0; i < 2; i++)
            {
                int index = i;
                modeButtons[i] = Button("Mode " + i, lobby.transform, new Vector2(0.04f + i * 0.225f, 0.32f), new Vector2(0.25f + i * 0.225f, 0.42f), i == 0 ? "Бой команд" : "Добыча", () => { mode = index; map = 0; UpdateSelection(); }, 22);
                mapButtons[i] = Button("Map " + i, lobby.transform, new Vector2(0.04f + i * 0.225f, 0.19f), new Vector2(0.25f + i * 0.225f, 0.29f), "", () => { map = index; UpdateSelection(); }, 22);
            }
            string[] names = { "Лёгкие", "Обычные", "Сложные" };
            for (int i = 0; i < 3; i++)
            {
                int index = i;
                botButtons[i] = Button("Difficulty " + i, lobby.transform, new Vector2(0.51f + i * 0.155f, 0.32f), new Vector2(0.65f + i * 0.155f, 0.42f), names[i], () => { difficulty = index; UpdateSelection(); }, 22);
            }
            var play = Button("Play", lobby.transform, new Vector2(0.63f, 0.06f), new Vector2(0.96f, 0.23f), "В БОЙ!", () =>
            {
                PlayerPrefs.SetInt("unity.hero", selected); PlayerPrefs.Save(); StartMatch?.Invoke(selected, difficulty, FindMap());
            }, 34); play.image.color = Blue;
            Label("Instructions", lobby.transform, new Vector2(0.04f, 0.03f), new Vector2(0.57f, 0.16f), "Слева — движение. Справа — тяни для прицела, отпусти для выстрела. Тап — автоприцел.", 20, TextAnchor.MiddleLeft);
            UpdateSelection();
        }
        int FindMap()
        {
            int n = 0; for (int i = 0; i < content.Maps.Length; i++) if (content.Maps[i].mode == (mode == 0 ? "teamfight" : "heist")) { if (n++ == map) return i; }
            throw new InvalidOperationException("Map selection missing");
        }
        void UpdateSelection()
        {
            for (int i = 0; i < 3; i++) { heroButtons[i].image.color = i == selected ? Blue : Panel; botButtons[i].image.color = i == difficulty ? Blue : Panel; }
            for (int i = 0; i < 2; i++) modeButtons[i].image.color = i == mode ? Blue : Panel;
            int n = 0;
            foreach (var m in content.Maps) if (m.mode == (mode == 0 ? "teamfight" : "heist"))
            {
                mapButtons[n].GetComponentInChildren<Text>().text = m.name; mapButtons[n].image.color = n == map ? Blue : Panel; n++;
            }
        }
        void BuildGameplay()
        {
            gameplay = Rect("Gameplay", SafeRoot, Vector2.zero, Vector2.one).gameObject;
            overheadRoot = Rect("Overhead HUD", gameplay.transform, Vector2.zero, Vector2.one);
            for (int i = 0; i < 6; i++)
            {
                var r = Rect("Brawler HUD " + i, overheadRoot, Vector2.one * 0.5f, Vector2.one * 0.5f); r.sizeDelta = new Vector2(100, 54); overhead[i] = r;
                hpLabels[i] = Label("Health text", r, new Vector2(0, 0.53f), new Vector2(1, 1), "", 17);
                var back = Box("Health background", r, new Vector2(0, 0.3f), new Vector2(1, 0.5f), Background);
                hp[i] = Box("Health", back.transform, Vector2.zero, Vector2.one, new Color32(72, 187, 120, 255));
                for (int j = 0; j < 3; j++)
                {
                    var slot = Box("Ammo background " + j, r, new Vector2(j / 3f + 0.01f, 0.06f), new Vector2((j + 1) / 3f - 0.01f, 0.2f), Background);
                    ammo[i, j] = Box("Ammo", slot.transform, Vector2.zero, Vector2.one, Gold);
                }
            }
            var top = Box("Scoreboard", gameplay.transform, new Vector2(0.24f, 0.88f), new Vector2(0.76f, 0.99f), Background);
            score = Label("Score", top.transform, Vector2.zero, new Vector2(0.7f, 1), "", 26);
            clock = Label("Clock", top.transform, new Vector2(0.72f, 0), Vector2.one, "", 26);
            Button("Pause", gameplay.transform, new Vector2(0.86f, 0.88f), new Vector2(0.98f, 0.99f), "Пауза", () => ShowPause(true), 22);
            playerStats = Label("Player stats", gameplay.transform, new Vector2(0.02f, 0.89f), new Vector2(0.23f, 0.99f), "", 22);
            banner = Label("Status", gameplay.transform, new Vector2(0.22f, 0.57f), new Vector2(0.78f, 0.77f), "", 40); banner.color = Gold;
            Movement = Stick("Movement", new Vector2(155, 145), new Vector2(0, 0), "ХОД", Blue, 210);
            Attack = Stick("Attack", new Vector2(-145, 145), new Vector2(1, 0), "ОГОНЬ", Red, 210); Attack.IsAction = true;
            Super = Stick("Super", new Vector2(-340, 110), new Vector2(1, 0), "СУПЕР", Gold, 132); Super.IsAction = true;
            superText = Super.GetComponentInChildren<Text>(); superRing = Super.GetComponent<Image>();
            overlay = Box("Pause and result", gameplay.transform, Vector2.zero, Vector2.one, new Color(0.06f, 0.08f, 0.11f, 0.96f), true).gameObject;
            Label("Overlay title", overlay.transform, new Vector2(0.15f, 0.6f), new Vector2(0.85f, 0.83f), "ПАУЗА", 40).name = "Overlay title";
            Button("Resume", overlay.transform, new Vector2(0.28f, 0.39f), new Vector2(0.72f, 0.53f), "Продолжить", () => ShowPause(false), 28);
            Button("Lobby", overlay.transform, new Vector2(0.28f, 0.2f), new Vector2(0.72f, 0.34f), "В лобби", () => LeaveMatch?.Invoke(), 28);
        }
        TouchStick Stick(string name, Vector2 position, Vector2 anchor, string label, Color color, float size)
        {
            var bg = Box(name, gameplay.transform, anchor, anchor, new Color(color.r, color.g, color.b, 0.76f), true);
            bg.sprite = disk; bg.rectTransform.sizeDelta = new Vector2(size, size); bg.rectTransform.anchoredPosition = position;
            var knob = Box("Handle", bg.transform, Vector2.one * 0.5f, Vector2.one * 0.5f, new Color(1, 1, 1, 0.35f));
            knob.sprite = disk; knob.rectTransform.sizeDelta = new Vector2(size * 0.45f, size * 0.45f);
            Label("Label", bg.transform, new Vector2(0.03f, 0.3f), new Vector2(0.97f, 0.7f), label, size > 150 ? 24 : 20).color = Color.white;
            var stick = bg.gameObject.AddComponent<TouchStick>(); stick.Initialize(knob.rectTransform); return stick;
        }
        void BuildSettings()
        {
            settings = Box("Settings", SafeRoot, Vector2.zero, Vector2.one, Background, true).gameObject;
            Label("Title", settings.transform, new Vector2(0.1f, 0.76f), new Vector2(0.9f, 0.94f), "НАСТРОЙКИ", 36).color = Gold;
            Button quality = null;
            quality = Button("Quality", settings.transform, new Vector2(0.2f, 0.56f), new Vector2(0.8f, 0.7f), "", () =>
            {
                LowQuality = !LowQuality; PlayerPrefs.SetInt("unity.lowQuality", LowQuality ? 1 : 0); PlayerPrefs.Save(); UpdateQualityText(quality); QualityChanged?.Invoke();
            }); UpdateQualityText(quality);
            Button sensitivity = null;
            Action updateSensitivity = () => sensitivity.GetComponentInChildren<Text>().text = "Чувствительность: " + Sensitivity.ToString("0.0");
            sensitivity = Button("Sensitivity", settings.transform, new Vector2(0.2f, 0.37f), new Vector2(0.8f, 0.51f), "", () =>
            {
                Sensitivity = Sensitivity > 1.3f ? 0.5f : Sensitivity + 0.25f; PlayerPrefs.SetFloat("unity.sensitivity", Sensitivity); PlayerPrefs.Save(); updateSensitivity();
            }); updateSensitivity();
            Button("Close settings", settings.transform, new Vector2(0.3f, 0.15f), new Vector2(0.7f, 0.29f), "Готово", () => settings.SetActive(false), 28);
            settings.SetActive(false);
        }
        void UpdateQualityText(Button b) { b.GetComponentInChildren<Text>().text = LowQuality ? "Экономия: 30 FPS" : "Плавность: 60 FPS"; }
        public void ShowLobby()
        { ResetControls(); lobby.SetActive(true); gameplay.SetActive(false); settings.SetActive(false); Paused = false; }
        public void ShowMatch()
        {
            ResetControls(); lobby.SetActive(false); gameplay.SetActive(true); overlay.SetActive(false); Paused = false;
            lastScore = lastClock = lastStats = lastBanner = lastSuper = null;
        }
        public void ShowPause(bool value)
        {
            ResetControls(); InputReset?.Invoke(); Paused = value; overlay.SetActive(value);
            overlay.transform.Find("Overlay title").GetComponent<Text>().text = "ПАУЗА";
            overlay.transform.Find("Resume").gameObject.SetActive(true);
        }
        public void ShowResult(MatchMode mode, Brawler player)
        {
            ResetControls(); overlay.SetActive(true);
            SetText(banner, ref lastBanner, "");
            SetText(score, ref lastScore, $"СВОИ  {mode.Scores[0]}  :  {mode.Scores[1]}  ВРАГИ");
            int seconds = Mathf.CeilToInt(mode.TicksLeft / 30f); SetText(clock, ref lastClock, $"{seconds / 60}:{seconds % 60:00}");
            overlay.transform.Find("Overlay title").GetComponent<Text>().text = (mode.Winner < 0 ? "НИЧЬЯ" : mode.Winner == 0 ? "ПОБЕДА" : "ПОРАЖЕНИЕ") + $"\n{mode.Scores[0]} : {mode.Scores[1]}    ·    Убийства {player.Kills}";
            overlay.transform.Find("Resume").gameObject.SetActive(false);
        }
        public void ResetControls() { Movement?.ResetInput(); Attack?.ResetInput(); Super?.ResetInput(); }
        public bool DismissSettings() { if (!settings.activeSelf) return false; settings.SetActive(false); return true; }
        static void SetText(Text label, ref string last, string next) { if (last == next) return; label.text = next; last = next; }
        public void Refresh(Match match, Camera camera, Transform[] views)
        {
            var w = match.World; var m = w.Mode; var p = match.Player;
            // HUD strings change at 10 Hz; health and movement still render every frame.
            if (Time.frameCount % 6 == 0 || lastScore == null)
            {
                SetText(score, ref lastScore, $"СВОИ  {m.Scores[0]}  :  {m.Scores[1]}  ВРАГИ");
                int seconds = Mathf.CeilToInt(m.TicksLeft / 30f); SetText(clock, ref lastClock, $"{seconds / 60}:{seconds % 60:00}");
                SetText(playerStats, ref lastStats, $"HP {p.Hp}\nЗаряды {p.Ammo}/{p.Data.max_ammo}");
                SetText(banner, ref lastBanner, m.Phase == MatchPhase.Countdown ? Mathf.CeilToInt((m.Countdown - w.Tick) / 30f).ToString() : !p.Alive ? "Возрождение " + Mathf.CeilToInt((p.RespawnAt - w.Tick) / 30f) : "");
                SetText(superText, ref lastSuper, p.SuperReady ? "СУПЕР" : p.SuperCharge / 10 + "%");
                superRing.color = p.SuperReady ? Gold : new Color(Gold.r * 0.55f, Gold.g * 0.55f, Gold.b * 0.55f, 0.8f);
            }
            for (int i = 0; i < w.Brawlers.Count; i++)
            {
                var b = w.Brawlers[i]; bool visible = w.Visible(0, b);
                if (overhead[i].gameObject.activeSelf != visible) overhead[i].gameObject.SetActive(visible);
                if (!visible) continue;
                var screen = camera.WorldToScreenPoint(views[i].position + Vector3.up * 2.0f);
                RectTransformUtility.ScreenPointToLocalPointInRectangle(overheadRoot, screen, null, out var position); overhead[i].anchoredPosition = position;
                hp[i].rectTransform.anchorMax = new Vector2(Mathf.Clamp01((float)b.Hp / b.Data.max_hp), 1);
                hp[i].color = b.ShieldUntil > w.Tick ? Color.cyan : b.Team == 0 ? new Color32(72, 187, 120, 255) : Red;
                if (Time.frameCount % 6 == 0) hpLabels[i].text = (b.Team == 0 ? "● " : "▼ ") + b.Hp + (b.Carried > 0 ? " +" + b.Carried : "");
                for (int j = 0; j < 3; j++) ammo[i, j].rectTransform.anchorMax = new Vector2(j < b.Ammo ? 1 : j == b.Ammo ? (float)b.Reload / World.Seconds(b.Data.reload_time) : 0, 1);
            }
        }
        Sprite MakeDisk()
        {
            var texture = new Texture2D(64, 64, TextureFormat.RGBA32, false); var pixels = new Color32[64 * 64];
            for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++) pixels[y * 64 + x] = new Color32(255, 255, 255, (byte)(Vector2.Distance(new Vector2(x, y), new Vector2(31.5f, 31.5f)) < 31 ? 255 : 0));
            texture.SetPixels32(pixels); texture.Apply(false, true); return Sprite.Create(texture, new Rect(0, 0, 64, 64), Vector2.one * 0.5f);
        }
        void OnDestroy() { if (disk != null) { Destroy(disk.texture); Destroy(disk); } }
    }
}
