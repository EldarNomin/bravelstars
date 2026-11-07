using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Bravel
{
    public sealed class TouchStick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public Vector2 Value { get; private set; }
        public bool Held { get; private set; }
        public bool IsAction;
        public System.Action<Vector2> Released;
        RectTransform area, knob;
        Vector2 actionStart;
        int pointer;
        public void Initialize(RectTransform handle) { area = (RectTransform)transform; knob = handle; }
        public void OnPointerDown(PointerEventData e)
        {
            if (Held) return;
            Held = true; pointer = e.pointerId;
            if (IsAction)
            {
                RectTransformUtility.ScreenPointToLocalPointInRectangle(area, e.position, e.pressEventCamera, out actionStart);
                Value = Vector2.zero; knob.anchoredPosition = Vector2.zero;
            }
            else Set(e);
        }
        public void OnDrag(PointerEventData e) { if (Held && pointer == e.pointerId) Set(e); }
        void Set(PointerEventData e)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(area, e.position, e.pressEventCamera, out var point);
            if (IsAction) point -= actionStart;
            Value = Vector2.ClampMagnitude(point / (area.rect.width * 0.38f), 1);
            knob.anchoredPosition = Value * (area.rect.width * 0.27f);
        }
        public void OnPointerUp(PointerEventData e)
        {
            if (!Held || pointer != e.pointerId) return;
            var aim = Value.sqrMagnitude < 0.025f ? Vector2.zero : Value;
            ResetInput(); if (IsAction) Released?.Invoke(aim);
        }
        public void ResetInput() { Held = false; Value = Vector2.zero; if (knob != null) knob.anchoredPosition = Vector2.zero; }
        void OnDisable() { ResetInput(); }
    }
}
