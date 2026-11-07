Shader "Bravel/Mobile Palette"
{
    Properties { _Color ("Color", Color) = (1,1,1,1) }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct v2f { float4 vertex : SV_POSITION; half shade : TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
            fixed4 _Color;
            v2f vert(appdata v)
            {
                v2f o; UNITY_SETUP_INSTANCE_ID(v); UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                half3 normal = UnityObjectToWorldNormal(v.normal);
                o.shade = 0.55 + 0.45 * saturate(dot(normal, normalize(half3(-0.3, 0.8, -0.5))));
                return o;
            }
            fixed4 frag(v2f i) : SV_Target { return fixed4(_Color.rgb * i.shade, 1); }
            ENDCG
        }
    }
    Fallback "Mobile/Diffuse"
}
