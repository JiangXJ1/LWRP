#ifndef SELF_SKIN_LIGHTING_H
#define SELF_SKIN_LIGHTING_H

#include "base.hlsl"
#include "effects.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _ReflectionCol;
half4 _SpecularColor;
half4 _BaseColor;
half _Cutoff;
half _BumpScale;
half _SpecularScale;

half _FogScale;
CBUFFER_END

TEXTURE2D(_BaseMap);			SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);			SAMPLER(sampler_BumpMap);
//r 曲率 g 光滑度 b 自发光
TEXTURE2D(_FinalMap);			SAMPLER(sampler_FinalMap);
TEXTURE2D(_SSSLUTMap);			SAMPLER(sampler_SSSLUTMap);
TEXTURE2D(_KelementLUTMap);		SAMPLER(sampler_KelementLUTMap);


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
	TANGENT_SPACE_COORDS

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	float4 shadowCoord	: TEXCOORD5;
#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

float4 GetShadowCoord(v2f v)
{
#if SHADOWS_SCREEN
	return ComputeScreenPos(v.positionCS);
#else
	return TransformWorldToShadowCoord(v.positionWS);
#endif
}

v2f vert(a2v v)
{
	v2f o;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	PosAndDirData data = InitPosData(v.vertex, v.normal, v.tangent);
	//切线空间
	o.tangentWS = data.tangentWS;
	o.bitangentWS = data.bitangentWS;
	o.viewWS = data.viewWS;
	o.normalWS = data.normalWS;
	o.positionWS = data.positionWS;
	o.positionCS = data.positionCS;
	o.uv = v.texcoord * _BaseMap_ST.xy + _BaseMap_ST.zw;
	
	o.fogFactorAndVertexLight = half4(CalcFogFactor(o.positionWS), VertexLighting(o.positionWS, o.normalWS));
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	o.shadowCoord = GetShadowCoord(o);
#endif

	OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV)
	OUTPUT_SH(o.normalWS, o.vertexSH);
	return o;
}

inline half3 DecodeTangetNormal(float2 uv, half3 normalWS, half3 tangentWS, half3 bitangentWS) {
	half3 N = normalWS;
	half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
	half3 tangentNormal = UnpackNormal(n);
	N.x = dot(float3(tangentWS.x, bitangentWS.x, normalWS.x), tangentNormal);
	N.y = dot(float3(tangentWS.y, bitangentWS.y, normalWS.y), tangentNormal);
	N.z = dot(float3(tangentWS.z, bitangentWS.z, normalWS.z), tangentNormal);
	return N;
}


inline half3 GetWorldNormal(v2f i) {
	return DecodeTangetNormal(i.uv, i.normalWS, i.tangentWS, i.bitangentWS);
}

//曲率 光滑度
inline half3 LightingSkin(half curve, half smooth, Light light, half3 gi, half3 N, half3 V, inout half3 specular)
{
	half3 L = light.direction;
	float lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
	half3 lightColor = light.color * lightAttenuation;
	half NdotL = dot(N, L);
	half3 diffuse = lightColor * SAMPLE_TEXTURE2D(_SSSLUTMap, sampler_SSSLUTMap, float2(NdotL*0.5 + 0.5, 0.1)).rgb;

#ifndef SPECULAR_OFF
	half3 H = normalize(L + V);
	half NdotH = saturate(dot(N, H));

	half4 KelementCol = SAMPLE_TEXTURE2D(_KelementLUTMap, sampler_KelementLUTMap, float2(NdotH, smooth)) * 2.0h;
	half3 PH = pow(abs(KelementCol.rgb), ((1.0h - _SpecularColor.a) + 0.05h) * 10.0h);

	half3 specColor = PH * _SpecularScale * _SpecularColor.rgb * lightColor;

#ifdef SPECULAR_ADD
	specular += specColor;
#else
	diffuse += specColor;
#endif

#endif
	return diffuse;
}

half4 fragSkin(v2f i) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
	half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
	col *= _BaseColor;
	//从gamma空间转换到线性空间
	//col.rgb = pow(col.rgb, 2.2f);

	half4 final = SAMPLE_TEXTURE2D(_FinalMap, sampler_FinalMap, i.uv);
	half3 N = GetWorldNormal(i);
	half3 V = i.viewWS;
	half3 gi = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	Light mainLight = GetMainLight(i.shadowCoord);
#else
	Light mainLight = GetMainLight();
#endif
	MixLightAndGI(mainLight, N, gi, half4(0, 0, 0, 1));


	half3 diffuse = gi;
	half3 specular = 0;
	diffuse += LightingSkin(final.r, final.g, mainLight, gi, N, V, specular);


#ifdef _ADDITIONAL_LIGHTS
	int pixelLightCount = GetAdditionalLightsCount();
	for (int idx = 0; idx < pixelLightCount; ++idx)
	{
		Light light = GetAdditionalLight(idx, i.positionWS);
		diffuse += LightingSkin(final.r, final.g, light, 1, N, V, specular);
	}
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	diffuse += i.fogFactorAndVertexLight.yzw * col.rgb;
#endif

	col.rgb = col.rgb * diffuse + specular;

	ApplyFogInfo(col, i.fogFactorAndVertexLight.x, _FogScale);
	return col;
}

#endif