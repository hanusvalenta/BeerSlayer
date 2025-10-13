Shader "Universal Render Pipeline/Custom/InstancedMeshGrass"
{
    Properties
    {
        _MainTex ("Grass Texture", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
        _GrassRandomness("Random Color Variations", Range(0,1)) = 0.5
        _BaseColor("Base Color", Color) = (0.2, 0.8, 0.2, 1)
        _ColorVariation("Color Variation", Range(0, 1)) = 0.3
        _WindStrength("Wind Strength", Range(0, 2)) = 0.5
        _WindSpeed("Wind Speed", Range(0, 5)) = 1.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "TransparentCutout" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Off
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct MeshProperties
            {
                float4x4 mat;
                float textureid;
                float4 color;
            };

            StructuredBuffer<MeshProperties> _Properties;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Cutoff;
                float _GrassRandomness;
                float4 _BaseColor;
                float _ColorVariation;
                float _WindStrength;
                float _WindSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                uint instanceID     : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 positionWS   : TEXCOORD2;
                float4 shadowCoord  : TEXCOORD3;
                float4 instanceColor : TEXCOORD4;
                float textureid     : TEXCOORD5;
            };

            float2 getTextureUnpacked(float2 uv, float i)
            {
                float2 index = float2(floor(i/2), floor(i/4));
                float2 uvOutput = uv;
                float2 texturePacking = float2(0.25, 0.5);
                float2 bounds = float2(0.01, 0.01);
                float2 offset = index * texturePacking;
                uvOutput = uvOutput * texturePacking;
                uvOutput = uvOutput + offset;
                uvOutput = clamp(uvOutput, offset + bounds, offset + texturePacking - bounds);
                return uvOutput;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                // Get instance properties
                MeshProperties props = _Properties[input.instanceID];
                
                // Apply instance transformation
                float4 positionOS = mul(props.mat, input.positionOS);
                
                // Add wind animation
                float windTime = _Time.y * _WindSpeed;
                float windOffset = sin(windTime + positionOS.x * 0.1) * _WindStrength * input.positionOS.y;
                positionOS.x += windOffset;
                
                output.positionWS = TransformObjectToWorld(positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.instanceColor = props.color;
                output.textureid = props.textureid;
                
                // Shadow coordinates
                #ifdef _MAIN_LIGHT_SHADOWS
                    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                #endif
                
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                // Get texture coordinates with atlas unpacking
                float2 uvTexture = getTextureUnpacked(input.uv, input.textureid);
                
                // Sample main texture
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvTexture);
                
                // Alpha cutoff
                clip(texColor.a - _Cutoff);
                
                // Base color with instance variation
                float4 finalColor = _BaseColor * input.instanceColor;
                finalColor.rgb = lerp(finalColor.rgb, texColor.rgb, 0.5);
                
                // Add color variation based on texture ID
                float colorVar = sin(input.textureid * 3.14159) * _ColorVariation;
                finalColor.rgb = lerp(finalColor.rgb, finalColor.rgb * (1.0 + colorVar), _GrassRandomness);
                
                // Lighting
                Light mainLight = GetMainLight(input.shadowCoord);
                float3 lightColor = mainLight.color;
                float lightAttenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                
                // Simple diffuse lighting
                float NdotL = saturate(dot(input.normalWS, mainLight.direction));
                float3 diffuse = lightColor * lightAttenuation * NdotL;
                
                // Ambient lighting
                float3 ambient = SampleSH(input.normalWS) * 0.5;
                
                finalColor.rgb *= (diffuse + ambient);
                finalColor.a = texColor.a;
                
                return finalColor;
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
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct MeshProperties
            {
                float4x4 mat;
                float textureid;
                float4 color;
            };

            StructuredBuffer<MeshProperties> _Properties;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Cutoff;
                float _WindStrength;
                float _WindSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                uint instanceID     : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float textureid     : TEXCOORD1;
            };

            float2 getTextureUnpacked(float2 uv, float i)
            {
                float2 index = float2(floor(i/2), floor(i/4));
                float2 uvOutput = uv;
                float2 texturePacking = float2(0.25, 0.5);
                float2 bounds = float2(0.01, 0.01);
                float2 offset = index * texturePacking;
                uvOutput = uvOutput * texturePacking;
                uvOutput = uvOutput + offset;
                uvOutput = clamp(uvOutput, offset + bounds, offset + texturePacking - bounds);
                return uvOutput;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                
                // Get instance properties
                MeshProperties props = _Properties[input.instanceID];
                
                // Apply instance transformation
                float4 positionOS = mul(props.mat, input.positionOS);
                
                // Add wind animation
                float windTime = _Time.y * _WindSpeed;
                float windOffset = sin(windTime + positionOS.x * 0.1) * _WindStrength * input.positionOS.y;
                positionOS.x += windOffset;
                
                float3 positionWS = TransformObjectToWorld(positionOS.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.textureid = props.textureid;
                
                return output;
            }

            float4 ShadowPassFragment(Varyings input) : SV_Target
            {
                // Get texture coordinates with atlas unpacking
                float2 uvTexture = getTextureUnpacked(input.uv, input.textureid);
                
                // Sample alpha for cutoff
                float alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvTexture).a;
                clip(alpha - _Cutoff);
                
                return 0;
            }
            ENDHLSL
        }
    }
}