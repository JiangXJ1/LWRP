// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "bump" {}
		[HideInInspector]_PlaneReflectMap("Ref Texture", 2D) = "black" {}
	
		_BaseColor("水体基本颜色", Color) = (0,0.5,0.5,1)
		_PlaneReflectColor("反射颜色", Color) = (1,1,1,1)
		_SpecColor("水面高光颜色", Color) = (0,0.5,0.5,1)
		//扰动速度xy 透明度控制 折射程度
		_BaseColorOffset("水体颜色控制", Vector) = (1,1,1,1)
		[Toggle(OPEN_BLOOM)]ShowBloom("产生辉光", Float) = 0
		[Toggle(RECEIVE_SHADOWS)]RecvShadow("接收阴影", Float) = 0
			
    }
    SubShader
    {
		Tags{"Queue"="Transparent+20" "RenderType" = "Transparent" "RenderPipeline" = "LightweightPipeline" "IgnoreProjector" = "True"}
        LOD 100
		ColorMask RGBA
		Blend One Zero
        Pass
        {
			Name "ForwardLit"
			Tags{"LightMode" = "LightweightForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			#pragma shader_feature OPEN_BLOOM
			#pragma shader_feature RECEIVE_SHADOWS

			#pragma multi_compile _ USING_REFLECTION

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

			#include "Library/base.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
            };
		 
            struct v2f
            {
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;

				float3 tangent : TANGENT;
				float3 normal : NORMAL;
				float3 bittangent : BITTANGENT;

				float3 view : TEXCOORD2;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
				float4 shadowCoord : TEXCOORD3;
#endif
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _BaseColor, _SpecColor, _BaseColorOffset;
			sampler2D _CameraDepthTexture;
			sampler2D _CameraOpaqueTexture;
			half4 _PlaneReflectColor;
#ifdef USING_REFLECTION
			half _ReflectFresnel;
			half _RefThreshold;
			uniform sampler2D _PlaneReflectMap;
#endif

            v2f vert (appdata v)
            {
                v2f o;
				o.worldPos = TransformObjectToWorld(v.vertex);
				o.vertex = TransformWorldToHClip(o.worldPos);
				o.screenPos = ComputeScreenPos(o.vertex);
				o.screenPos.z = -TransformWorldToView(o.worldPos).z;

				VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
				o.normal = normalInputs.normalWS;
				o.tangent = normalInputs.tangentWS;
				o.bittangent = normalInputs.bitangentWS;

				half3 viewDirWS = GetCameraPositionWS() - o.worldPos;
				o.view = normalize(viewDirWS);

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
				o.shadowCoord = GetShadowCoord(o.vertex, o.worldPos);
#endif
				OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV)
				OUTPUT_SH(o.normal, o.vertexSH);
                return o;
            }

			//通过扰动参数采样图片
			float4 tex2DFlow(sampler2D tex, float2 uv, float2 speed) 
			{
				half offset = _Time.x * speed;
				return (tex2D(tex, uv + offset) + tex2D(tex, half2(-uv.y, uv.x) - offset)) * 0.5;
			}

			inline void LightingBlinnPhone(Light light, half3 N, half3 V, half4 specControl, inout half3 diffuseColor, inout half3 specularColor)
			{
				half3 L = light.direction;
				half3 H = normalize(L + V);
				float NdotL = saturate(dot(N, L));
				float NdotH = saturate(dot(N, H));
				half3 lightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
				diffuseColor += lightColor * NdotL;
				specularColor += pow(NdotH, (1 - specControl.a) * 50 + 4) * specControl.rgb * lightColor;
			}

            float4 frag (v2f i) : SV_Target
            {

				float2 uvScreen = i.screenPos.xy / i.screenPos.w;

				float depth = tex2D(_CameraDepthTexture, uvScreen).r;
				float sceneZ = LinearEyeDepth(depth, _ZBufferParams);
				//return float4(depth, depth, depth, 1);
				float diff = max(sceneZ - i.screenPos.z, 0); // 两个值都在同一空间下, 就可以做比较了

				half2 uvMain = i.worldPos.xz * _MainTex_ST.xy + _MainTex_ST.zw;
				half3 tangentNormal = UnpackNormal(tex2DFlow(_MainTex, uvMain, _BaseColorOffset.xy / 10));

				half3 N;
				N.x = dot(half3(i.tangent.x, i.bittangent.x, i.normal.x), tangentNormal);
				N.y = dot(half3(i.tangent.y, i.bittangent.y, i.normal.y), tangentNormal);
				N.z = dot(half3(i.tangent.z, i.bittangent.z, i.normal.z), tangentNormal);

				//折射颜色
				half2 uv_offseted = uvScreen + tangentNormal.xy * _BaseColorOffset.w;

				half4 color1 = tex2D(_CameraOpaqueTexture, uv_offseted);
				_BaseColor.rgb = lerp(color1.rgb, _BaseColor.rgb, saturate(diff / _BaseColorOffset.z * 10) * _BaseColor.a);

				//反射颜色
				half3 V = i.view;
				float NdotV = saturate(dot(N, V));
				_BaseColor.rgb = lerp(_BaseColor.rgb, _PlaneReflectColor.rgb, NdotV * NdotV);

				half3 gi = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normal);
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
				Light light = GetMainLight(i.shadowCoord);
#else
				Light light = GetMainLight();
#endif
				MixLightAndGI(light, i.normal, gi, half4(0, 0, 0, 1));
				half3 diffuseColor = gi;
				half3 specularColor = half3(0, 0, 0);
				half3 lightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
				LightingBlinnPhone(light, N, V, _SpecColor, diffuseColor, specularColor);

				//return half4(_BaseColor.a, _BaseColor.a, _BaseColor.a, 1);
#ifdef _ADDITIONAL_LIGHTS
				int pixelLightCount = GetAdditionalLightsCount();
				for (int idx = 0; idx < pixelLightCount; ++idx)
				{
					Light lightinfo = GetAdditionalLight(idx, i.worldPos);
					LightingBlinnPhone(lightinfo, N, V, _SpecColor, diffuseColor, specularColor);
				}
#endif

				_BaseColor.rgb = _BaseColor.rgb * diffuseColor;

#ifdef USING_REFLECTION
				half4 refColor = tex2D(_PlaneReflectMap, uv_offseted);
				half scale = _ReflectFresnel + (1 - _ReflectFresnel) * Pow5(NdotV);
				half maxcol = max(refColor.r, max(refColor.g, refColor.b));
				_BaseColor.rgb = lerp(_BaseColor.rgb, refColor.rgb, scale * step(_RefThreshold, maxcol));
#endif

				_BaseColor.rgb += specularColor;
#ifdef OPEN_BLOOM
				_BaseColor.a = 0.95h;
#else
				_BaseColor.a = 0;
#endif
                return _BaseColor;
            }
            ENDHLSL
        }
    }
}
