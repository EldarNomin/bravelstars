using System;
using System.Collections;
using System.IO;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Bravel.Sim;

namespace Bravel
{
    public sealed class RuntimeSmoke : MonoBehaviour
    {
        BravelGame game;
        string output;
        int errors;
        void OnEnable() { Application.logMessageReceived += OnLog; }
        void OnDisable() { Application.logMessageReceived -= OnLog; }
        void OnLog(string message, string trace, LogType type)
        {
            if (type != LogType.Error && type != LogType.Exception && type != LogType.Assert) return;
            errors++;
            if (output != null) File.WriteAllText(Path.Combine(output, "runtime-failed.txt"), message + "\n" + trace);
            Application.Quit(1);
        }
        IEnumerator Start()
        {
            game = GetComponent<BravelGame>(); string[] args = Environment.GetCommandLineArgs(); int index = Array.IndexOf(args, "-bravelEvidence");
            output = index >= 0 && index + 1 < args.Length ? args[index + 1] : Path.Combine(Application.persistentDataPath, "smoke");
            Directory.CreateDirectory(output); yield return new WaitForSecondsRealtime(1);
            yield return Capture("lobby");
            for (int hero = 0; hero < 3; hero++)
            {
                int map = 0; while (game.Content.Maps[map].mode != (hero == 2 ? "heist" : "teamfight")) map++;
                game.StartMatch(hero, 1, map, 17 + hero, true); yield return new WaitForSecondsRealtime(0.5f);
                for (int tick = game.Match.World.Tick; tick < 120; tick++) { game.Match.Step(default); game.Match.World.Events.Clear(); }
                yield return null;
                TouchChecks(); yield return new WaitForSecondsRealtime(0.2f);
                yield return Capture("spawn-" + game.Content.Heroes[hero].id);
                for (int tick = game.Match.World.Tick; tick < 600 && game.Match.World.Mode.Phase != MatchPhase.Finished; tick++) { game.Match.Step(default); game.Match.World.Events.Clear(); }
                yield return new WaitForSecondsRealtime(0.4f);
                yield return Capture("match-" + game.Content.Heroes[hero].id);
                game.Ui.ShowPause(true); int before = game.Match.World.Tick; yield return new WaitForSecondsRealtime(0.2f);
                Require(game.Match.World.Tick == before, "Pause advanced simulation"); game.Ui.ShowPause(false);
                for (int i = 0; i < 4600 && game.Match.World.Mode.Phase != MatchPhase.Finished; i++) { game.Match.Step(default); game.Match.World.Events.Clear(); }
                Require(game.Match.World.Mode.Phase == MatchPhase.Finished, "Runtime match did not finish");
                yield return null;
                var status = game.Ui.transform.Find("Safe area/Gameplay/Status").GetComponent<Text>();
                Require(status.text == "", "Result kept a respawn/countdown banner");
                yield return Capture("result-" + hero);
                game.LeaveMatch(); yield return null;
            }
            game.StartMatch(0, 1, 0, 1); yield return null;
            game.SendMessage("OnApplicationPause", true); int paused = game.Match.World.Tick;
            yield return new WaitForSecondsRealtime(0.2f); Require(game.Match.World.Tick == paused, "Background advanced match");
            game.SendMessage("OnApplicationPause", false); Require(game.Ui.Paused, "Resume must stay paused"); game.Ui.ShowPause(false);
            game.LeaveMatch(); yield return null;
            if (errors != 0) throw new Exception("Smoke console errors: " + errors);
            File.WriteAllText(Path.Combine(output, "runtime.txt"), $"RUNTIME_SMOKE_PASSED {Screen.width}x{Screen.height}\nThree heroes; both modes; complete matches; lobby return; pause/resume; simultaneous pointer IDs; pointer cancel; safe-area layout; nonblank offscreen renders.\n");
            Debug.Log("RUNTIME_SMOKE_PASSED"); Application.Quit(0);
        }
        void TouchChecks()
        {
            var left = game.Ui.Movement; var right = game.Ui.Attack; var super = game.Ui.Super;
            PointerEventData a = Pointer(left, 11), b = Pointer(right, 12), c = Pointer(super, 13);
            left.OnPointerDown(a); right.OnPointerDown(b); super.OnPointerDown(c);
            Require(left.Held && right.Held && super.Held, "Independent pointers were rejected");
            a.position += new Vector2(40, 30); left.OnDrag(a); b.position += new Vector2(30, 20); right.OnDrag(b);
            Require(left.Value.sqrMagnitude > 0 && right.Value.sqrMagnitude > 0, "Concurrent movement/aim");
            right.OnPointerUp(a); Require(right.Held, "Foreign pointer released attack");
            left.OnPointerUp(a); right.OnPointerUp(b); super.OnPointerUp(c);
            Require(!left.Held && !right.Held && !super.Held, "Pointer release stuck");
            left.OnPointerDown(a); game.Ui.ShowPause(true); Require(!left.Held && left.Value == Vector2.zero, "Pause did not reset pointer"); game.Ui.ShowPause(false);
            Canvas.ForceUpdateCanvases();
            foreach (var button in game.Ui.GetComponentsInChildren<Button>()) Require(button.GetComponent<RectTransform>().rect.height >= 60, "Touch button too small: " + button.name);
            foreach (var stick in new[] { left, right, super })
            {
                var corners = new Vector3[4]; stick.GetComponent<RectTransform>().GetWorldCorners(corners);
                var safe = Screen.safeArea; foreach (var corner in corners) Require(corner.x >= safe.xMin - 1 && corner.x <= safe.xMax + 1 && corner.y >= safe.yMin - 1 && corner.y <= safe.yMax + 1, "Stick outside safe area: " + stick.name);
            }
        }
        static PointerEventData Pointer(TouchStick stick, int id) => new PointerEventData(EventSystem.current) { pointerId = id, position = RectTransformUtility.WorldToScreenPoint(null, stick.transform.position) };
        static void Require(bool value, string message) { if (!value) throw new Exception(message); }
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();
            var canvas = game.Ui.GetComponent<Canvas>(); var mode = canvas.renderMode; var camera = canvas.worldCamera;
            var target = RenderTexture.GetTemporary(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32);
            var previous = RenderTexture.active; var texture = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
            try
            {
                // A hidden desktop window has no reliable swapchain image; render the same scene/UI explicitly.
                canvas.renderMode = RenderMode.ScreenSpaceCamera; canvas.worldCamera = game.Camera; canvas.planeDistance = 1;
                game.Camera.targetTexture = target; Canvas.ForceUpdateCanvases(); game.Camera.Render();
                RenderTexture.active = target; texture.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0); texture.Apply();
                var pixels = texture.GetPixels32(); int min = 765, max = 0;
                for (int i = 0; i < pixels.Length; i += 97) { int sum = pixels[i].r + pixels[i].g + pixels[i].b; min = Math.Min(min, sum); max = Math.Max(max, sum); }
                Require(max - min > 50, "Blank render: " + name);
                File.WriteAllBytes(Path.Combine(output, name + ".png"), texture.EncodeToPNG());
            }
            finally
            {
                game.Camera.targetTexture = null; canvas.renderMode = mode; canvas.worldCamera = camera;
                RenderTexture.active = previous; RenderTexture.ReleaseTemporary(target); Destroy(texture);
            }
            yield return null;
        }
    }
}
