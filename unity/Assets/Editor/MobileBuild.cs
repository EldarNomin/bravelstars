using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using Bravel.Checks;
using Bravel.Sim;

namespace Bravel.Editor
{
    public static class MobileBuild
    {
        const string ScenePath = "Assets/Scenes/Bravel.unity";
        [MenuItem("Bravel/Configure mobile project")]
        public static void Configure()
        {
            ConfigureClips();
            PlayerSettings.companyName = "Bravel"; PlayerSettings.productName = "Bravel Stars"; PlayerSettings.bundleVersion = "0.1.0";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.bravel.arena.unity");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToLandscapeLeft = PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.allowedAutorotateToPortrait = PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.defaultScreenWidth = 1280; PlayerSettings.defaultScreenHeight = 720;
            PlayerSettings.runInBackground = false; PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetSdkVersion = (AndroidSdkVersions)36; PlayerSettings.Android.bundleVersionCode = 1;
            PlayerSettings.Android.optimizedFramePacing = true; PlayerSettings.Android.startInFullscreen = true;
            PlayerSettings.Android.renderOutsideSafeArea = true;
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.OpenGLES3 });
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.Android, ManagedStrippingLevel.Low);
            PlayerSettings.stripEngineCode = true; PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.useCustomKeystore = false;
            QualitySettings.vSyncCount = 0; QualitySettings.shadows = ShadowQuality.Disable; QualitySettings.antiAliasing = 2; QualitySettings.pixelLightCount = 0;
            Time.fixedDeltaTime = World.Dt; Time.maximumDeltaTime = 0.1f;
            if (!File.Exists(ScenePath))
            {
                Directory.CreateDirectory("Assets/Scenes"); var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                EditorSceneManager.SaveScene(scene, ScenePath);
            }
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            var serialized = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var input = serialized.FindProperty("activeInputHandler"); if (input != null) { input.intValue = 0; serialized.ApplyModifiedPropertiesWithoutUndo(); }
            AssetDatabase.SaveAssets(); Debug.Log("MOBILE_PROJECT_CONFIGURED");
        }
        [MenuItem("Bravel/Validate simulation and assets")]
        public static void Validate()
        {
            var content = new Content();
            SimulationChecks.Run(content.Heroes, content.Balance, content.Maps, Debug.Log);
            foreach (var hero in content.Heroes)
            {
                string path = "Assets/Resources/Models/heroes/" + hero.id + ".fbx";
                var model = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (model == null || model.GetComponent<Animation>() == null) throw new Exception("Hero import failed: " + hero.id);
                var clips = AssetDatabase.LoadAllAssetsAtPath(path); int count = 0;
                foreach (string action in new[] { "idle", "run", "attack", "super", "death" })
                {
                    bool found = false; foreach (var clip in clips) if (clip is AnimationClip a && a.name == action && a.length > 0 && a.legacy) { found = true; count++; }
                    if (!found) throw new Exception("Missing clip: " + hero.id + "/" + action);
                }
                Debug.Log("HERO_IMPORT_OK " + hero.id + " clips=" + count);
            }
            foreach (var path in AssetDatabase.FindAssets("t:Material", new[] { "Assets/Resources/Models" }))
            {
                var material = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(path));
                if (material != null && (material.shader == null || !material.shader.isSupported)) throw new Exception("Unsupported material: " + material.name);
            }
            ValidateLayout(); Debug.Log("UNITY_VALIDATION_PASSED");
        }
        static void ConfigureClips()
        {
            foreach (string id in new[] { "lynx", "anvil", "shishka" })
            {
                string path = "Assets/Resources/Models/heroes/" + id + ".fbx";
                var importer = (ModelImporter)AssetImporter.GetAtPath(path);
                if (importer.clipAnimations.Length == 5) continue;
                var clips = importer.defaultClipAnimations;
                if (clips.Length != 5) throw new Exception("Expected five source takes: " + id);
                foreach (var clip in clips)
                {
                    foreach (string action in new[] { "idle", "run", "attack", "super", "death" }) if (clip.name.ToLowerInvariant().Contains(action))
                    { clip.name = action; clip.loopTime = clip.loopPose = action == "idle" || action == "run"; clip.wrapMode = clip.loopTime ? WrapMode.Loop : WrapMode.Once; break; }
                }
                importer.clipAnimations = clips; importer.SaveAndReimport();
            }
        }
        static void ValidateLayout()
        {
            foreach (var size in new[] { new Vector2(1280, 720), new Vector2(2340, 1080), new Vector2(2048, 1536), new Vector2(2400, 1080) })
            {
                var r = MobileLayout.NormalizedSafeArea(new Rect(80, 30, size.x - 130, size.y - 50), (int)size.x, (int)size.y);
                if (r.xMin < 0 || r.yMin < 0 || r.xMax > 1 || r.yMax > 1 || r.width <= 0) throw new Exception("Safe area invalid");
                if (MobileLayout.CameraHalfHeight(size.x / size.y) * size.x / size.y < 12) throw new Exception("Camera narrower than 24 tiles");
            }
        }
        [MenuItem("Bravel/Build Android APK (development)")]
        public static void Android()
        {
            Configure(); Validate(); EditorUserBuildSettings.buildAppBundle = false;
            Build(BuildTarget.Android, "Builds/Android/bravelstars-unity-debug.apk");
        }
        [MenuItem("Bravel/Build Windows smoke player")]
        public static void Windows()
        {
            Configure(); Validate(); Build(BuildTarget.StandaloneWindows64, "Builds/Windows/Bravel.exe");
        }
        static void Build(BuildTarget target, string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            { scenes = new[] { ScenePath }, target = target, locationPathName = path, options = BuildOptions.Development | BuildOptions.StrictMode });
            if (report.summary.result != BuildResult.Succeeded) throw new Exception("Build failed: " + report.summary.result);
            Debug.Log($"BUILD_PASSED {path} bytes={report.summary.totalSize} seconds={report.summary.totalTime.TotalSeconds:0.0}");
        }
    }
}
