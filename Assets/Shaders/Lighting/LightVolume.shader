Shader "Custom/PixelArtLightVolume"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Surface Color", Color) = (1,1,1,1)
        _HaloColor ("Halo Color", Color) = (1,1,0.5,0.5)
        
        _SurfaceQuantization ("Surface Quantization", Range(2, 32)) = 8
        _HaloQuantization ("Halo Quantization", Range(2, 16)) = 3
        
        _Halo ("Halo Intensity", Range(0, 2)) = 0.55
        _HaloSize ("Halo Size", Range(0.01, 0.5)) = 0.046
        _OutlineThreshold ("Outline Threshold", Range(0, 10)) = 5
        _CornerBrightness ("Corner Brightness", Range(0, 1)) = 0.5
        
        _LightPosition ("Light Position", Vector) = (0.5, 0.5, 0, 0)
        _LightRange ("Light Range", Float) = 10.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always
            Cull Off
            
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
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            float4 _Color;
            float4 _HaloColor;
            float _SurfaceQuantization;
            float _HaloQuantization;
            float _Halo;
            float _HaloSize;
            float _OutlineThreshold;
            float _CornerBrightness;
            float4 _LightPosition;
            float _LightRange;
            
            // Quantize function for pixel art effect
            float quantizeFloat(float value, float steps)
            {
                return floor(value * steps + 0.5) / steps;
            }
            
            float3 quantize(float3 color, float steps)
            {
                return floor(color * steps + 0.5) / steps;
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.worldPos = vertexInput.positionWS;
                output.screenPos = ComputeScreenPos(vertexInput.positionCS);
                output.uv = input.uv;
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // Get screen space coordinates
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                
                // Calculate distance from light position (in screen space or world space)
                float2 lightScreenPos = _LightPosition.xy;
                float distanceFromLight = distance(screenUV, lightScreenPos);
                
                // Alternative: use world space distance if you want 3D volumetric effect
                // float3 lightWorldPos = float3(_LightPosition.x, _LightPosition.y, _LightPosition.z);
                // float distanceFromLight = distance(input.worldPos, lightWorldPos) / _LightRange;
                
                // Create volumetric falloff
                float attenuation = 1.0 - saturate(distanceFromLight / _HaloSize);
                attenuation = pow(attenuation, _Halo);
                
                // Quantize the attenuation for pixel art effect
                float quantizedAttenuation = quantizeFloat(attenuation, _HaloQuantization);
                
                // Create inner core with different quantization
                float core = 1.0 - saturate(distanceFromLight / (_HaloSize * 0.3));
                core = quantizeFloat(core, _SurfaceQuantization);
                
                // Create stepped outline
                float outline = 0;
                float edgeDistance = abs(distanceFromLight - _HaloSize * 0.8);
                if (edgeDistance < 0.02)
                {
                    outline = _CornerBrightness;
                    outline = quantizeFloat(outline, _SurfaceQuantization);
                }
                
                // Combine effects
                float3 coreColor = quantize(_Color.rgb * core, _SurfaceQuantization);
                float3 haloColor = quantize(_HaloColor.rgb * quantizedAttenuation, _HaloQuantization);
                float3 outlineColor = quantize(float3(1,1,1) * outline, _SurfaceQuantization);
                
                // Final composition
                float3 finalColor = max(coreColor, haloColor) + outlineColor;
                
                // Calculate alpha with proper falloff
                float alpha = max(quantizedAttenuation, core) + outline;
                alpha = saturate(alpha) * _HaloColor.a;
                
                // Fade out at edges to avoid hard cutoff
                float edgeFade = 1.0 - smoothstep(0.9, 1.0, distanceFromLight / _HaloSize);
                alpha *= edgeFade;
                
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}