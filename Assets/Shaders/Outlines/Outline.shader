Shader "Custom/URP/ToonDepthNormalOutline"
{
    Properties
    {
        [Header(Main Texture)]
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        
        [Header(Toon Shading)]
        _ToonSteps ("Toon Steps", Range(2, 5)) = 3
        _ToonSmoothness ("Toon Smoothness", Range(0.0, 0.02)) = 0.001
        _ShadowColor ("Shadow Color", Color) = (0.5,0.4,0.3,1)
        _LightColor ("Light Color", Color) = (1,1,1,1)
        _MidColor ("Mid Color", Color) = (0.8,0.7,0.6,1)
        
        [Header(Outline Settings)]
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineThickness ("Outline Thickness", Range(0.5, 5.0)) = 1.0
        
        [Header(Detection Settings)]
        _DepthSensitivity ("Depth Sensitivity", Range(0, 100)) = 1
        _NormalsSensitivity ("Normals Sensitivity", Range(0, 100)) = 1
        _DepthNormalMix ("Depth/Normal Mix", Range(0, 1)) = 0.5
        
        [Header(Outline Variations)]
        _InnerLineScale ("Inner Line Scale", Range(0.1, 1.0)) = 0.5
        _OutlineOnly ("Outline Only (Debug)", Range(0, 1)) = 0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        LOD 100
        
        Pass
        {
            Name "MainPass"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float fogFactor : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
            };
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float4 _OutlineColor;
                float4 _ShadowColor;
                float4 _LightColor;
                float4 _MidColor;
                float _OutlineThickness;
                float _DepthSensitivity;
                float _NormalsSensitivity;
                float _DepthNormalMix;
                float _InnerLineScale;
                float _OutlineOnly;
                float _ToonSteps;
                float _ToonSmoothness;
            CBUFFER_END
            
            // Convert screen space thickness to world space to maintain consistent pixel size
            float2 GetConsistentTexelSize(float4 positionCS)
            {
                // Calculate world space pixel size at current depth
                float depth = positionCS.w;
                float2 screenTexelSize = _OutlineThickness / _ScreenParams.xy;
                
                // Scale by depth to maintain consistent world-space thickness
                return screenTexelSize * depth;
            }
            
            float GetDepthOutline(float2 uv, float4 positionCS)
            {
                float2 texelSize = GetConsistentTexelSize(positionCS);
                
                float centerDepth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
                
                float4 depthSamples;
                depthSamples.x = LinearEyeDepth(SampleSceneDepth(uv + float2(texelSize.x, 0)), _ZBufferParams);
                depthSamples.y = LinearEyeDepth(SampleSceneDepth(uv - float2(texelSize.x, 0)), _ZBufferParams);
                depthSamples.z = LinearEyeDepth(SampleSceneDepth(uv + float2(0, texelSize.y)), _ZBufferParams);
                depthSamples.w = LinearEyeDepth(SampleSceneDepth(uv - float2(0, texelSize.y)), _ZBufferParams);
                
                float depthDiff = 0;
                depthDiff = max(depthDiff, abs(centerDepth - depthSamples.x));
                depthDiff = max(depthDiff, abs(centerDepth - depthSamples.y));
                depthDiff = max(depthDiff, abs(centerDepth - depthSamples.z));
                depthDiff = max(depthDiff, abs(centerDepth - depthSamples.w));
                
                return saturate(depthDiff * _DepthSensitivity);
            }
            
            float GetNormalOutline(float2 uv, float4 positionCS)
            {
                float2 texelSize = GetConsistentTexelSize(positionCS);
                
                float3 centerNormal = SampleSceneNormals(uv);
                
                float3 normalSample1 = SampleSceneNormals(uv + float2(texelSize.x, 0));
                float3 normalSample2 = SampleSceneNormals(uv - float2(texelSize.x, 0));
                float3 normalSample3 = SampleSceneNormals(uv + float2(0, texelSize.y));
                float3 normalSample4 = SampleSceneNormals(uv - float2(0, texelSize.y));
                
                float normalDiff = 0;
                normalDiff = max(normalDiff, 1 - dot(centerNormal, normalSample1));
                normalDiff = max(normalDiff, 1 - dot(centerNormal, normalSample2));
                normalDiff = max(normalDiff, 1 - dot(centerNormal, normalSample3));
                normalDiff = max(normalDiff, 1 - dot(centerNormal, normalSample4));
                
                return saturate(normalDiff * _NormalsSensitivity);
            }
            
            float GetInnerOutline(float2 uv, float4 positionCS)
            {
                float2 texelSize = GetConsistentTexelSize(positionCS) * _InnerLineScale;
                
                float3 centerNormal = SampleSceneNormals(uv);
                float centerDepth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
                
                // Sample in a cross pattern for inner details
                float outline = 0;
                
                for(int i = -1; i <= 1; i++)
                {
                    for(int j = -1; j <= 1; j++)
                    {
                        if(i == 0 && j == 0) continue;
                        
                        float2 sampleUV = uv + float2(i, j) * texelSize;
                        float3 sampleNormal = SampleSceneNormals(sampleUV);
                        float sampleDepth = LinearEyeDepth(SampleSceneDepth(sampleUV), _ZBufferParams);
                        
                        float normalDiff = 1 - dot(centerNormal, sampleNormal);
                        float depthDiff = abs(centerDepth - sampleDepth);
                        
                        outline = max(outline, normalDiff * _NormalsSensitivity * 0.5);
                        outline = max(outline, depthDiff * _DepthSensitivity * 0.5);
                    }
                }
                
                return saturate(outline);
            }
            
            // Pixel-perfect toon shading function for voxel style
            float3 CalculateVoxelLighting(float3 normal, float3 lightDir, float3 lightColor, float shadowAttenuation, float3 baseColor)
            {
                float NdotL = dot(normal, lightDir);
                float lightIntensity = saturate(NdotL) * shadowAttenuation;
                
                // Create very sharp lighting transitions for pixel art look
                float3 finalColor;
                
                if (lightIntensity > 0.7)
                {
                    // Bright lit areas - use light color multiplied by base
                    finalColor = baseColor * _LightColor.rgb * 1.2;
                }
                else if (lightIntensity > 0.3)
                {
                    // Medium lit areas - use mid tone
                    finalColor = baseColor * _MidColor.rgb;
                }
                else
                {
                    // Shadow areas - use shadow color
                    finalColor = baseColor * _ShadowColor.rgb;
                }
                
                return finalColor;
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;
                
                output.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                output.shadowCoord = GetShadowCoord(positionInputs);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // Get screen space UV
                float2 screenUV = input.positionCS.xy / _ScreenParams.xy;
                
                // Sample base texture
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _BaseColor;
                
                // Calculate voxel-style lighting
                Light mainLight = GetMainLight(input.shadowCoord);
                float3 normalWS = normalize(input.normalWS);
                
                float3 voxelColor = CalculateVoxelLighting(normalWS, mainLight.direction, mainLight.color, mainLight.shadowAttenuation, baseColor.rgb);
                
                // Get outline values
                float depthOutline = GetDepthOutline(screenUV, input.positionCS);
                float normalOutline = GetNormalOutline(screenUV, input.positionCS);
                float innerOutline = GetInnerOutline(screenUV, input.positionCS);
                
                // Mix depth and normal outlines
                float outerOutline = lerp(depthOutline, normalOutline, _DepthNormalMix);
                
                // Combine outer and inner outlines
                float finalOutline = max(outerOutline, innerOutline * 0.7);
                finalOutline = saturate(finalOutline);
                
                // Apply outline to the voxel-lit color
                half3 finalColor = lerp(voxelColor, _OutlineColor.rgb, finalOutline);
                
                // Debug mode - show only outlines
                if(_OutlineOnly > 0.5)
                {
                    finalColor = lerp(half3(1,1,1), _OutlineColor.rgb, finalOutline);
                }
                
                // Apply fog
                finalColor = MixFog(finalColor, input.fogFactor);
                
                return half4(finalColor, baseColor.a);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthNormalsOnly"
            Tags { "LightMode" = "DepthNormalsOnly" }
            
            ZWrite On
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                return half4(normalize(input.normalWS), 0);
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Unlit"
}