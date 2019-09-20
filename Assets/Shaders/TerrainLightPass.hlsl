#ifndef TERRAIN_LIGHT_PASS
#define TERRAIN_LIGHT_PASS
#include "Library/base.hlsl"
#include "Library/effects.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _SplatMap0_ST;
float4 _SplatMap1_ST;
float4 _SplatMap2_ST;
float4 _SplatMap3_ST;

half4 _BaseColor0;
half4 _BaseColor1;
half4 _BaseColor2;
half4 _BaseColor3;

half4 _SpecColor0;
half4 _SpecColor1;
half4 _SpecColor2;
half4 _SpecColor3;

half _FogScale;
CBUFFER_END

TEXTURE2D(_Control);			SAMPLER(sampler_Control);

TEXTURE2D(_BumpMap0);			SAMPLER(sampler_BumpMap0);
TEXTURE2D(_SplatMap0);			SAMPLER(sampler_SplatMap0);

TEXTURE2D(_BumpMap1);			SAMPLER(sampler_BumpMap1);
TEXTURE2D(_SplatMap1);			SAMPLER(sampler_SplatMap1);

TEXTURE2D(_BumpMap2);			SAMPLER(sampler_BumpMap2);
TEXTURE2D(_SplatMap2);			SAMPLER(sampler_SplatMap2);

TEXTURE2D(_BumpMap3);			SAMPLER(sampler_BumpMap3);
TEXTURE2D(_SplatMap3);			SAMPLER(sampler_SplatMap3);

struct a2v
{
	half4 vertex : POSITION;
	half3 normal : NORMAL;
	half4 tangent : TANGENT;
	float2 texcoord : TEXCOORD0;
	float2 lightmapUV : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	half4 positionCS	: SV_POSITION;
	float2 uv			: TEXCOORD0;
	half3 viewWS		: TEXCOORD1;
#ifdef _ADDITIONAL_LIGHTS
	half3 positionWS	: TEXCOORD2;
#endif
	half3 normalWS		: NORMAL;
	DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
	half4 fogFactorAndVertexLight   : TEXCOORD4; // x: fogFactor, yzw: vertex light

#ifdef _MAIN_LIGHT_SHADOWS
	float4 shadowCoord	: TEXCOORD5;
#endif

#if defined(USED_SPLAT0) || defined(USED_SPLAT1)
	float4 uv01			: TEXCOORD6;
#endif
#if defined(USED_SPLAT2) || defined(USED_SPLAT3)
	float4 uv23			: TEXCOORD7;
#endif

	half3 tangentWS	: TANGENT;
	half3 bitangentWS : BITTANGENT;

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
	//ÇÐÏß¿Õ¼ä
	o.tangentWS = data.tangentWS;
	o.bitangentWS = data.bitangentWS;

	o.viewWS = data.viewWS;
	o.normalWS = data.normalWS;

#ifdef _ADDITIONAL_LIGHTS
	o.positionWS = data.positionWS;
#endif

	o.positionCS = data.positionCS;
	o.uv = v.texcoord;
#ifdef USED_SPLAT0
	o.uv01.xy = v.texcoord * _SplatMap0_ST.xy + _SplatMap0_ST.zw;
#endif
#ifdef USED_SPLAT1
	o.uv01.zw = v.texcoord * _SplatMap1_ST.xy + _SplatMap1_ST.zw;
#endif
#ifdef USED_SPLAT2
	o.uv23.xy = v.texcoord * _SplatMap2_ST.xy + _SplatMap2_ST.zw;
#endif
#ifdef USED_SPLAT3
	o.uv23.zw = v.texcoord * _SplatMap3_ST.xy + _SplatMap3_ST.zw;
#endif

	o.fogFactorAndVertexLight = half4(CalcFogFactor(data.positionWS), VertexLighting(data.positionWS, data.normalWS));
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
	o.shadowCoord = GetShadowCoord(data.positionCS, data.positionWS);
#endif

	OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV)
	OUTPUT_SH(o.normalWS, o.vertexSH);
	return o;
}

half3 CalcLightingInfo(Light light, half3 gi, half specScale, half3 N, half3 V, half4 specColor, inout half3 specular)
{
	half3 L = light.direction;
	half NdotL = saturate(dot(N, L));
	float lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
	half3 lightColor = light.color * lightAttenuation;
	half3 diffuse = lightColor * NdotL;
#ifndef SPECULAR_OFF
	half3 H = normalize(L + V);
	half NdotH = saturate(dot(N, H));
	half3 specularColor = pow(NdotH, specColor.a * 40 + 5) * specColor.rgb * specScale * lightColor;
#ifdef SPECULAR_ADD
	specular += specularColor;
#else
	diffuse += specularColor;
#endif
#endif
	return diffuse;
}

inline half3 DecodeTangetNormal(float2 uv, TEXTURE2D_PARAM(_BumpMap, sampler_BumpMap),  half3 normalWS, half3 tangentWS, half3 bitangentWS) {
	half3 N = normalWS;
	half3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv));
	N.x = dot(float3(tangentWS.x, bitangentWS.x, normalWS.x), tangentNormal);
	N.y = dot(float3(tangentWS.y, bitangentWS.y, normalWS.y), tangentNormal);
	N.z = dot(float3(tangentWS.z, bitangentWS.z, normalWS.z), tangentNormal);
	return N;
}

#define NORMAL_COORD(idx, i, uv)\
	half3 Normal##idx=DecodeTangetNormal(uv, TEXTURE2D_ARGS(_BumpMap##idx, sampler_BumpMap##idx), i.normalWS, i.tangentWS, i.bitangentWS);

#define LIGHT_COLOR_CALC(light, gi, specScale, idx) CalcLightingInfo(light, gi, specScale, Normal##idx, i.viewWS, _SpecColor##idx, specular##idx);

half4 frag(v2f i) :SV_Target
{
	half3 gi = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

#if defined(_MAIN_LIGHT_SHADOWS)
	Light mainLight = GetMainLight(i.shadowCoord);
#else
	Light mainLight = GetMainLight();
#endif

	MixLightAndGI(mainLight, i.normalWS, gi, half4(0, 0, 0, 1));
	

#ifdef USED_SPLAT0
	half3 diffuse0 = gi;
	half3 specular0 = 0;
	half4 col0 = SAMPLE_TEXTURE2D(_SplatMap0, sampler_SplatMap0, i.uv01.xy) * _BaseColor0;
	NORMAL_COORD(0, i, i.uv01.xy);
	diffuse0 += LIGHT_COLOR_CALC(mainLight, gi, col0.a, 0);
#else
	half4 col0 = _BaseColor0;
#endif

#ifdef USED_SPLAT1
	half3 diffuse1 = gi;
	half3 specular1 = 0;
	half4 col1 = SAMPLE_TEXTURE2D(_SplatMap1, sampler_SplatMap1, i.uv01.zw) * _BaseColor1;

	NORMAL_COORD(1, i, i.uv01.zw);
	diffuse1 += LIGHT_COLOR_CALC(mainLight, gi, col1.a, 1);
#else
	half4 col1 = _BaseColor1;
#endif

#ifdef USED_SPLAT2
	half3 diffuse2 = gi;
	half3 specular2 = 0;
	half4 col2 = SAMPLE_TEXTURE2D(_SplatMap2, sampler_SplatMap2, i.uv23.xy) * _BaseColor2;

	NORMAL_COORD(2, i, i.uv23.xy);
	diffuse2 += LIGHT_COLOR_CALC(mainLight, gi, col2.a, 2);
#else
	half4 col2 = _BaseColor2;
#endif

#ifdef USED_SPLAT3
	half3 diffuse3 = gi;
	half3 specular3 = 0;
	half4 col3 = SAMPLE_TEXTURE2D(_SplatMap3, sampler_SplatMap3, i.uv23.zw) * _BaseColor3;

	NORMAL_COORD(3, i, i.uv23.zw);
	diffuse2 += LIGHT_COLOR_CALC(mainLight, gi, col3.a, 3);
#else
	half4 col3 = _BaseColor3;
#endif

#ifdef _ADDITIONAL_LIGHTS
	int pixelLightCount = GetAdditionalLightsCount();
	for (int idx = 0; idx < pixelLightCount; ++idx)
	{
		Light light = GetAdditionalLight(idx, i.positionWS);
#ifdef USED_SPLAT0
		diffuse0 += LIGHT_COLOR_CALC(light, 1, col0.a, 0);
#endif
#ifdef USED_SPLAT1
		diffuse1 += LIGHT_COLOR_CALC(light, 1, col1.a, 1);
#endif
#ifdef USED_SPLAT2
		diffuse2 += LIGHT_COLOR_CALC(light, 1, col2.a, 2);
#endif
#ifdef USED_SPLAT3
		diffuse3 += LIGHT_COLOR_CALC(light, 1, col3.a, 3);
#endif
	}
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	//return half4(i.fogFactorAndVertexLight.yzw, 1);
	#ifdef USED_SPLAT0
		diffuse0 += i.fogFactorAndVertexLight.yzw;
	#endif
	#ifdef USED_SPLAT1
		diffuse1 += i.fogFactorAndVertexLight.yzw;
	#endif
	#ifdef USED_SPLAT2
		diffuse2 += i.fogFactorAndVertexLight.yzw;
	#endif
	#ifdef USED_SPLAT3
		diffuse3 += i.fogFactorAndVertexLight.yzw;
	#endif
#endif

#ifdef USED_SPLAT0
	col0.rgb *= diffuse0;
	col0.rgb += specular0;
#endif
#ifdef USED_SPLAT1
	col1.rgb *= diffuse1;
	col1.rgb += specular1;
#endif
#ifdef USED_SPLAT2
	col2.rgb *= diffuse2;
	col2.rgb += specular2;
#endif
#ifdef USED_SPLAT3
	col3.rgb *= diffuse3;
	col3.rgb += specular3;
#endif

	half4 col = half4(0, 0, 0, 1);
	half4 ctrl = SAMPLE_TEXTURE2D(_Control, sampler_Control, i.uv);
	col.rgb = col0.rgb * ctrl.r + col1.rgb * ctrl.g + col2.rgb * ctrl.b + col3.rgb * ctrl.a;

	return col;
}

#endif
