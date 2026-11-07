using System;
using UnityEngine;
using Bravel.Sim;

namespace Bravel
{
    public sealed class BravelGame : MonoBehaviour
    {
        public Match Match { get; private set; }
        public GameUi Ui { get; private set; }
        public ArenaView View { get; private set; }
        public Camera Camera { get; private set; }
        public Content Content { get; private set; }
        float accumulator;
        bool attackQueued, superQueued, suspended, resultShown;
        Vec attackAim, superAim;
        Vector3 cameraFocus;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (FindFirstObjectByType<BravelGame>() == null) new GameObject("Bravel game").AddComponent<BravelGame>();
        }
        void Awake()
        {
            Screen.orientation = ScreenOrientation.AutoRotation; Screen.autorotateToPortrait = Screen.autorotateToPortraitUpsideDown = false;
            Screen.autorotateToLandscapeLeft = Screen.autorotateToLandscapeRight = true;
            Input.multiTouchEnabled = true; Input.simulateMouseWithTouches = false;
            Content = new Content(); var cameraGo = new GameObject("Arena camera", typeof(Camera)); Camera = cameraGo.GetComponent<Camera>();
            Camera.clearFlags = CameraClearFlags.SolidColor; Camera.backgroundColor = GameUi.Background; Camera.orthographic = true; Camera.nearClipPlane = 0.1f; Camera.farClipPlane = 100;
            Camera.transform.rotation = Quaternion.Euler(55, 0, 0);
            var uiGo = new GameObject("Mobile interface", typeof(RectTransform)); Ui = uiGo.AddComponent<GameUi>(); Ui.Initialize(Content);
            Ui.StartMatch = (hero, difficulty, map) => StartMatch(hero, difficulty, map);
            Ui.LeaveMatch = LeaveMatch; Ui.QualityChanged = ApplyQuality; Ui.InputReset = ResetInput;
            Ui.Attack.Released = value => { if (!CanInput()) return; attackQueued = true; attackAim = Aim(value, Match.Player.Data.attack); };
            Ui.Super.Released = value => { if (!CanInput()) return; superQueued = true; superAim = Aim(value, Match.Player.Data.super_attack); };
            ApplyQuality();
            if (Array.IndexOf(Environment.GetCommandLineArgs(), "-bravelSmoke") >= 0) gameObject.AddComponent<RuntimeSmoke>();
        }
        bool CanInput() => Match != null && !suspended && !Ui.Paused && Match.World.Mode.Phase == MatchPhase.Playing;
        Vec Aim(Vector2 input, AttackData data) => new Vec(input.x, input.y) * data.range_tiles;
        public void ApplyQuality()
        {
            QualitySettings.vSyncCount = 0; QualitySettings.shadows = ShadowQuality.Disable; QualitySettings.antiAliasing = Ui.LowQuality ? 0 : 2;
            QualitySettings.pixelLightCount = 0; Application.targetFrameRate = Ui.LowQuality ? 30 : 60;
            // Bound framebuffer fill rate on high-resolution phones.
            if (Application.isMobilePlatform)
            {
                int width = Mathf.Max(Display.main.systemWidth, Display.main.systemHeight), height = Mathf.Min(Display.main.systemWidth, Display.main.systemHeight);
                float scale = Mathf.Min(1, (Ui.LowQuality ? 1600f : 1920) / width);
                Screen.SetResolution(Mathf.RoundToInt(width * scale), Mathf.RoundToInt(height * scale), FullScreenMode.FullScreenWindow);
            }
        }
        public void StartMatch(int hero, int difficulty, int map, int seed = 0, bool botsOnly = false)
        {
            if (View != null) { View.gameObject.SetActive(false); Destroy(View.gameObject); }
            Match = new Match(Content.Maps[map], Content.Heroes, Content.Balance, hero, difficulty, seed == 0 ? Environment.TickCount : seed, botsOnly);
            var go = new GameObject("Match view"); View = go.AddComponent<ArenaView>(); View.Initialize(Match);
            accumulator = 0; resultShown = false; suspended = false; Ui.ShowMatch(); ResetInput();
            cameraFocus = ArenaView.Position(Match.Player.Position); UpdateCamera(true);
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
        }
        public void LeaveMatch()
        {
            ResetInput(); Match = null; if (View != null) { View.gameObject.SetActive(false); Destroy(View.gameObject); View = null; }
            Ui.ShowLobby(); Screen.sleepTimeout = SleepTimeout.SystemSetting;
        }
        public void ResetInput() { attackQueued = superQueued = false; attackAim = superAim = default; accumulator = 0; Ui?.ResetControls(); }
        void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                if (Ui.DismissSettings()) return;
                if (Match != null && Match.World.Mode.Phase != MatchPhase.Finished) Ui.ShowPause(!Ui.Paused);
                else if (Match != null) LeaveMatch();
            }
            if (Match == null || suspended || Ui.Paused) return;
            if (Match.World.Mode.Phase == MatchPhase.Finished)
            { if (!resultShown) { resultShown = true; Ui.ShowResult(Match.World.Mode, Match.Player); Screen.sleepTimeout = SleepTimeout.SystemSetting; } return; }
            var keyboard = new Vector2((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0), (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0));
            if (Input.GetKeyDown(KeyCode.Q) && CanInput()) superQueued = true;
            if (Input.GetKey(KeyCode.Space) && CanInput()) attackQueued = true;
            accumulator += Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            while (accumulator >= World.Dt)
            {
                var move = Vector2.ClampMagnitude(Ui.Movement.Value * Ui.Sensitivity + keyboard, 1);
                var cmd = new Command { Move = new Vec(move.x, move.y), Attack = attackQueued, Aim = attackAim, Super = superQueued, SuperAim = superAim };
                attackQueued = superQueued = false; Match.Step(cmd);
                foreach (var e in Match.World.Events) View.Event(e, Match.World); Match.World.Events.Clear();
                accumulator -= World.Dt;
            }
            var aim = Ui.Super.Held ? Ui.Super.Value : Ui.Attack.Value;
            View.Render(Match, accumulator / World.Dt, aim, Ui.Attack.Held || Ui.Super.Held, Ui.Super.Held);
            UpdateCamera(false); Ui.Refresh(Match, Camera, View.Heroes);
        }
        void UpdateCamera(bool snap)
        {
            float halfHeight = MobileLayout.CameraHalfHeight(Camera.aspect); Camera.orthographicSize = halfHeight;
            float halfWidth = halfHeight * Camera.aspect;
            Vector3 goal = View.Heroes[Match.Player.Index].position; var map = Match.World.Map;
            float groundHalfDepth = halfHeight / Mathf.Sin(55 * Mathf.Deg2Rad);
            goal.x = ClampCenter(goal.x, map.Width, halfWidth); goal.z = ClampCenter(goal.z, map.Height, groundHalfDepth); goal.y = 0;
            cameraFocus = snap ? goal : Vector3.Lerp(cameraFocus, goal, 1 - Mathf.Exp(-8 * Time.unscaledDeltaTime));
            Camera.transform.position = cameraFocus - Camera.transform.forward * 26;
        }
        // Allow some arena margin so a player at spawn never sits under a thumb control.
        static float ClampCenter(float value, int size, float half)
        { float margin = Mathf.Min(size * 0.5f, half * 0.5f); return Mathf.Clamp(value, margin, size - margin); }
        void OnApplicationPause(bool pause)
        {
            suspended = pause; ResetInput();
            if (pause && Match != null && Match.World.Mode.Phase != MatchPhase.Finished) Ui.ShowPause(true);
        }
        void OnApplicationFocus(bool focus) { if (!focus) { ResetInput(); if (Match != null && Match.World.Mode.Phase != MatchPhase.Finished) Ui.ShowPause(true); } }
        void OnDestroy()
        {
            if (Ui != null) Destroy(Ui.gameObject); if (Camera != null) Destroy(Camera.gameObject);
            if (View != null) Destroy(View.gameObject);
            Screen.sleepTimeout = SleepTimeout.SystemSetting;
        }
    }
}
