#ifndef SELF_LIGHTING_H
#define SELF_LIGHTING_H

#include "brdf.hlsl"
#include "effects.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _ReflectionCol;
half4 _SpecularColor;
half4 _BaseColor;
half _Cutoff;
half _Roughness;
half _Metalness;
half _BumpScale;

#ifdef OPEN_EMMISION
half4 _EmissionColor;
#endif

#ifdef OPEN_RIM
half4 _RimColor;
half4 _RimDirection;
half _RimTweenSpeed;
#endif

#ifdef USED_FOG
half _FogScale;
#endif

#ifdef OPEN_BLOOM
half _BloomScale;
#endif

#ifdef LIGHT_ANISO
half _AnisoOffset1;
half _AnisoOffset2;
#endif

#ifdef USING_REFLECTION
half4 _PlaneReflectColor;
half _ReflectFresnel;
half _RefThreshold;
#endif

CBUFFER_END

TEXTURE2D(_BaseMap);			SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);			SAMPLER(sampler_BumpMap);
TEXTURE2D(_AnisoMap);			SAMPLER(sampler_AnisoMap);

TEXTURE2D(_FinalMap);			SAMPLER(sampler_FinalMap);
TEXTURE2D(_ReflectMatCap);		SAMPLER(sampler_ReflectMatCap);
TEXTURE2D(_EffectMask);			SAMPLER(sampler_EffectMask);


struct a2v
{
	half4 vertex : POSITION;
	half3 normal : NORMAL;
	TANGENT_SPACE_BASE_COORDS
	float2 texcoord : TEXCOORD0;
	float2 lightmapUV : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	half4 positionCS	: SV_POSITION;
	float2 uv			: TEXCOORD0;
	half3 viewWS		: TEXCOORD1;
	half3 positionWS	: TEXCOORD2;
	half3 normalWS		: NORMAL;
	DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
	half4 fogFactorAndVertexLight   : TEXCOORD4; // x: fogFactor, yzw: vertex light
#if defined(USED_BUMPMAP) || defined(LIGHT_ANISO)
	TANGENT_SPACE_COORDS
#endif

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	float4 shadowCoord	: TEXCOORD5;
#endif

#ifdef USING_REFLECTION
	float4 positionSS : TEXCOORD7;
#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

v2f vert(a2v v)
{
	v2f o;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	PosAndDirData data = InitPosData(v.vertex, v.normal, v.tangent);
	//切线空间
#if defined(USED_BUMPMAP) || defined(LIGHT_ANISO)
	o.tangentWS = data.tangentWS;
	o.bitangentWS = data.bitangentWS;
#endif
	o.viewWS = data.viewWS;
	o.normalWS = data.normalWS;
	o.positionWS = data.positionWS;
	o.positionCS = data.positionCS;
	o.uv = v.texcoord * _BaseMap_ST.xy + _BaseMap_ST.zw;
	
	o.fogFactorAndVertexLight = half4(CalcFogFactor(o.positionWS), VertexLighting(o.positionWS, o.normalWS));
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	o.shadowCoord = GetShadowCoord(o.positionCS, o.positionWS);
#endif

#ifdef USING_REFLECTION
	o.positionSS = ComputeScreenPos(o.positionCS);
#endif

	OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV)
	OUTPUT_SH(o.normalWS, o.vertexSH);
	return o;
}

inline half4 SampleMatcap(v2f i) 
{
	float2 uvMatcap = CalcUVMatCap(i.normalWS, i.viewWS);
	return SAMPLE_TEXTURE2D(_ReflectMatCap, sampler_ReflectMatCap, uvMatcap) * _ReflectionCol;
}


inline half3 DecodeTangetNormal(float2 uv, half3 normalWS, half3 tangentWS, half3 bitangentWS) {
	half3 N = normalWS;
	half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
#ifdef BUMPMAP_SCALE
	half3 tangentNormal = UnpackNormal(n);
#else
	half3 tangentNormal = UnpackNormalScale(n, _BumpScale);
#endif
	N.x = dot(float3(tangentWS.x, bitangentWS.x, normalWS.x), tangentNormal);
	N.y = dot(float3(tangentWS.y, bitangentWS.y, normalWS.y), tangentNormal);
	N.z = dot(float3(tangentWS.z, bitangentWS.z, normalWS.z), tangentNormal);
	return N;
}

inline half3 GetWorldNormal(v2f i) {
#if defined(USED_BUMPMAP)
	return DecodeTangetNormal(i.uv, i.normalWS, i.tangentWS, i.bitangentWS);
#else
	return i.normalWS;
#endif
}

inline half SpecScale(v2f i, half3 L, half3 N, half3 V, half roughness, half metallic)
{
	half3 H = normalize(L + V);
	half NdotH = saturate(dot(N, H));
#ifdef LIGHT_ANISO
	half NdotL = saturate(dot(N, L));
	half NdotV = saturate(dot(N, V)) + 0.01;

	half3 anisotropicDir = UnpackNormal(SAMPLE_TEXTURE2D(_AnisoMap, sampler_AnisoMap, i.uv));
	half3 binormalDirection = cross(N, anisotropicDir);
	half dotHDirRough1 = dot(H, anisotropicDir) / _AnisoOffset1;
	half dotHBRough2 = dot(H, binormalDirection) / _AnisoOffset2;

	half scale = sqrt(NdotL / NdotV) * exp(-2.0 * (dotHDirRough1 * dotHDirRough1 + dotHBRough2 * dotHBRough2) / (1.0 + NdotH));
#else
	half scale = pow(NdotH, metallic * 40 + 5);
#endif
	return scale * roughness;
}

inline half3 CalcBlinPhong(Light light, v2f i, half3 N, half roughness, half metallic, inout half3 specular)
{
	half3 V = i.viewWS;
	half3 L = light.direction;
	half NdotL = saturate(dot(N, L));

	float lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
	half3 lightColor = light.color * lightAttenuation;
	half3 diffuse = lightColor * NdotL;

#ifndef SPECULAR_OFF
	half specScale = SpecScale(i, L, N, V, roughness, metallic);
	half3 specColor = specScale * _SpecularColor.rgb * lightColor.rgb;
#ifdef SPECULAR_ADD
	specular += specColor;
#else
	diffuse += specColor;
#endif
#endif
	return diffuse;
}

half3 LightingBlinPhong(v2f i, half3 N, half4 incolor, half4 final, half3 gi) 
{
	half metallic = _Metalness * final.r;
	half roughness = 1 - _Roughness * final.g;

	half NdotV = abs(dot(N, i.viewWS));
	//half3 outcol = lerp(incolor.rgb, reflectCol.rgb, lerp(0.3h, 1, metallic) * pow(NdotV, (1 - reflectCol.a) * 10 + 1));
	half3 outcol = incolor.rgb;// lerp(incolor.rgb, reflectCol.rgb, lerp(0.3h, 1, metallic) * pow(NdotV, (1 - reflectCol.a) * 10 + 1));
	half3 diffuse = gi;
	half3 specular = 0;

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	Light mainLight = GetMainLight(i.shadowCoord);
#else
	Light mainLight = GetMainLight();
#endif
	MixLightAndGI(mainLight, i.normalWS, gi, half4(0, 0, 0, 1));
	diffuse += CalcBlinPhong(mainLight, i, N, roughness, metallic, specular);
#ifdef _ADDITIONAL_LIGHTS
	int pixelLightCount = GetAdditionalLightsCount();
	for (int idx = 0; idx < pixelLightCount; ++idx)
	{
		Light light = GetAdditionalLight(idx, i.positionWS);
		diffuse += CalcBlinPhong(light, i, N, roughness, metallic, specular);
	}
#endif

	return outcol * diffuse + specular;
}

half4 fragDefault(v2f i) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
	half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
	col *= _BaseColor;
#if defined(_ALPHATEST_ON) && !defined(RENDER_TRANSPARENT)
	clip(col.a - _Cutoff - 0.01f);
#endif
	//从gamma空间转换到线性空间
	//col.rgb = pow(col.rgb, 2.2f);

	half4 final = SAMPLE_TEXTURE2D(_FinalMap, sampler_FinalMap, i.uv);
	half3 N = GetWorldNormal(i);
	half3 V = i.viewWS;
	half3 gi = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

#ifdef LIGHT_BRDF
	half4 reflectColor = SampleMatcap(i);
	LightingBRDF(col.rgb, col, N, V, gi, _SpecularColor, reflectColor.rgb, i.fogFactorAndVertexLight.yzw, final, _Metalness, _Roughness, i.positionWS, i.shadowCoord);
#elif LIGHT_PHONG || LIGHT_ANISO
	col.rgb = LightingBlinPhong(i, N, col, final, gi);
#elif LIGHT_ONLYGI
	col.rgb *= gi;
#endif

#if OPEN_EMMISION
	ApplyEmmision(col, _EmissionColor, final.g);
#endif

	//边缘光
#ifdef OPEN_RIM
	ApplyRim(col, _RimColor, i.normalWS, i.viewWS, _RimDirection.xyz, _RimTweenSpeed);
#endif

	half3 effFinal = SAMPLE_TEXTURE2D(_EffectMask, sampler_EffectMask, i.uv).rgb;

#ifdef USING_REFLECTION
	half NdotV = 1 - saturate(dot(N, V));
	half scale = _ReflectFresnel + (1 - _ReflectFresnel) * Pow5(NdotV);
	ApplyPlannerReflection(col, i.positionSS, _PlaneReflectColor, _RefThreshold, effFinal.g * scale * _PlaneReflectColor.a);
#endif
#if USED_FOG
	ApplyFogInfo(col, i.fogFactorAndVertexLight.x, _FogScale);
#endif
	return col;
}

#endif