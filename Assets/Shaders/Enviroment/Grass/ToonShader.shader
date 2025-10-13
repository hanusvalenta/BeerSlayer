Shader "Custom/ToonShaderURP"
{
    Properties
    {
        [Header(Base Parameters)]
        _Color ("Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
        _Specular ("Specular Color", Color) = (1,1,1,1)
        [HDR]_Emission ("Emission", Color) = (0, 0, 0, 1)

        [Header(Lighting Parameters)]
        _ShadowTint ("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
        [IntRange]_StepAmount ("Shadow Steps", Range(1, 16)) = 2
        _StepWidth ("Step Size", Range(0, 1)) = 0.25
        _SpecularSize ("Specular Size", Range(0, 1)) = 0.1
        _SpecularFalloff ("Specular Falloff", Range(0, 2)) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 viewDirWS  : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float4 _Specular;
            float4 _Emission;
            float4 _ShadowTint;
            float _StepWidth;
            float _StepAmount;
            float _SpecularSize;
            float _SpecularFalloff;

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = normalize(TransformObjectToWorldNormal(v.normalOS));
                o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                float3 normal = normalize(i.normalWS);
                float3 viewDir = normalize(i.viewDirWS);

                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = max(0, dot(normal, lightDir));

                // Stepped shading
                float stepped = floor(NdotL / _StepWidth);
                stepped = (stepped + step(0, frac(NdotL / _StepWidth))) / _StepAmount;
                stepped = saturate(stepped);

                // ✅ Get shadow attenuation properly
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                float shadowAtten = MainLightRealtimeShadow(shadowCoord);
                stepped *= shadowAtten;

                // Specular highlight
                float3 refl = reflect(-lightDir, normal);
                float towardsRefl = dot(viewDir, refl);
                float falloff = pow(dot(viewDir, normal), _SpecularFalloff);
                towardsRefl *= falloff;
                float spec = step(1 - _SpecularSize, towardsRefl) * shadowAtten;

                // Final color
                float3 litColor = albedo * stepped * mainLight.color;
                litColor = lerp(litColor, _Specular.rgb * mainLight.color, saturate(spec));

                // Shadow tint
                litColor = lerp(litColor, albedo * _ShadowTint.rgb, 1 - stepped);

                // Add emission
                litColor += _Emission.rgb;

                return float4(litColor, 1);
            }

            ENDHLSL
        }
    }
    FallBack Off
}
