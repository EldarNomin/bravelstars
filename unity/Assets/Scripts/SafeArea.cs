using UnityEngine;

namespace Bravel
{
    public static class MobileLayout
    {
        public static Rect NormalizedSafeArea(Rect area, int width, int height)
        {
            if (width <= 0 || height <= 0) return new Rect(0, 0, 1, 1);
            float x0 = Mathf.Clamp01(area.xMin / width), y0 = Mathf.Clamp01(area.yMin / height);
            float x1 = Mathf.Clamp01(area.xMax / width), y1 = Mathf.Clamp01(area.yMax / height);
            return x1 <= x0 || y1 <= y0 ? new Rect(0, 0, 1, 1) : Rect.MinMaxRect(x0, y0, x1, y1);
        }
        public static float CameraHalfHeight(float aspect) => Mathf.Max(6.5f, 12f / Mathf.Max(1, aspect));
    }

    public sealed class SafeArea : MonoBehaviour
    {
        Rect previous;
        int width, height;
        public System.Action Changed;
        void LateUpdate()
        {
            Rect safe = Screen.safeArea;
            if (safe == previous && width == Screen.width && height == Screen.height) return;
            previous = safe; width = Screen.width; height = Screen.height;
            Apply(safe, width, height); Changed?.Invoke();
        }
        public void Apply(Rect safe, int w, int h)
        {
            var r = MobileLayout.NormalizedSafeArea(safe, w, h); var rt = (RectTransform)transform;
            rt.anchorMin = r.min; rt.anchorMax = r.max; rt.offsetMin = rt.offsetMax = Vector2.zero;
        }
    }
}
