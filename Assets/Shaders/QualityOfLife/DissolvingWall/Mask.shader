Shader "Custom/WallWithConeMask_DepthCam"
{
    Properties
    {
        _BaseMap("Base Texture", 2D) = "white" {}
        _DepthMap("Depth Map", 2D) = "white" {}
        _Radius("Base Radius", Float) = 1.0
        _FadeWidth("Fade Width", Float) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_DepthMap);
            SAMPLER(sampler_DepthMap);

            float _Radius;
            float _FadeWidth;

            float4 _PlayerPos;
            float4x4 _DepthCam_VP; // Secondary camera VP matrix

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                // --- Transform fragment into secondary camera clip space ---
                float4 fragHCS = mul(_DepthCam_VP, float4(IN.positionWS,1));
                float2 screenUV = fragHCS.xy / fragHCS.w * 0.5 + 0.5;

                // --- Sample depth from secondary camera ---
                float fragDepth = SAMPLE_TEXTURE2D(_DepthMap, sampler_DepthMap, screenUV).r;

                // --- Player depth in secondary camera ---
                float4 playerHCS = mul(_DepthCam_VP, float4(_PlayerPos.xyz,1));
                float playerDepth = playerHCS.z / playerHCS.w;

                // --- Only dissolve if fragment is behind player ---
                if (fragDepth > playerDepth)
                {
                    float3 fragView = TransformWorldToView(IN.positionWS);
                    float3 playerView = TransformWorldToView(_PlayerPos.xyz);

                    float2 diff = fragView.xy - playerView.xy;
                    float dist = length(diff);

                    float dynamicRadius = _Radius * (abs(playerView.z) * 0.1);

                    float alpha = 1.0;
                    if (dist < dynamicRadius)
                        alpha = 0.0;
                    else if (dist < dynamicRadius + _FadeWidth)
                        alpha = saturate((dist - dynamicRadius) / _FadeWidth);

                    baseColor.a = alpha;
                }
                else
                {
                    baseColor.a = 1.0;
                }

                return baseColor;
            }

            ENDHLSL
        }
    }
}
