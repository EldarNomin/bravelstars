using System;
using UnityEditor;
using UnityEngine;

namespace Bravel.Editor
{
    public sealed class ModelImport : AssetPostprocessor
    {
        void OnPreprocessModel()
        {
            if (!assetPath.StartsWith("Assets/Resources/Models/", StringComparison.Ordinal)) return;
            var importer = (ModelImporter)assetImporter;
            importer.globalScale = 1; importer.useFileScale = true; importer.addCollider = false;
            importer.isReadable = !assetPath.Contains("/heroes/"); importer.importCameras = importer.importLights = false;
            importer.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
            importer.animationType = ModelImporterAnimationType.Legacy; importer.importAnimation = assetPath.Contains("/heroes/");
        }
        void OnPostprocessMaterial(Material material)
        {
            if (!assetPath.StartsWith("Assets/Resources/Models/", StringComparison.Ordinal)) return;
            Color color = material.HasProperty("_Color") ? material.color : Color.white;
            material.shader = Shader.Find("Bravel/Mobile Palette"); material.color = color; material.enableInstancing = true;
        }
    }
}
