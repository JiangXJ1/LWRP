#ifndef SHADER_LIB_BASE
#define SHADER_LIB_BASE

#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"

#define TANGENT_SPACE_BASE_COORDS\
		half4	tangent			: TANGENT;

#define TANGENT_SPACE_COORDS\
		half3	tangentWS			: TANGENT;\
		half3	bitangentWS		: BITTANGENT;

struct PosAndDirData {
	half3 viewWS;
	half3 normalWS;
	half4 positionCS;
	half3 positionWS;
	half3 tangentWS;
	half3 bitangentWS;
};

inline float CalcCurvature(half3 normalOS, half3 positionOS) 
{
	return saturate(length(fwidth(normalOS)) / length(fwidth(positionOS)));
}

inline float2 CalcUVMatCap(half3 normal, half3 viewWS)
{
	float2 uvMatcap;
	float4x4 it_mv = UNITY_MATRIX_IT_MV;
	half3 normalOS = TransformWorldToObjectDir(normal);
	half3 viewOS = TransformWorldToObjectDir(viewWS);
	half3 objLight = reflect(normalOS, viewOS);
	uvMatcap.x = dot(normalize(it_mv[0].xyz), objLight) / 2 + 0.5f;
	uvMatcap.y = dot(normalize(it_mv[1].xyz), objLight) / 2 + 0.5f;
	return uvMatcap;
}

void MixLightAndGI(inout Light light, half3 normalWS, inout half3 bakedGI, half4 shadowMask)
{
#if defined(LIGHTMAP_ON)
	bakedGI = SubtractDirectMainLightFromLightmap(light, normalWS, bakedGI);
#endif
}

//inline half4 SampleTextureBlur(TEXTURE2D_PARAM(texName, sampler_texName), float2 uv, float2 uvoffset)
//{
//	half4 uv1 = uv.xyxy + uvoffset.xyxy * float4(-1, 1, 0, 1);
//	half4 uv2 = uv.xyxy + uvoffset.xyxy * float4(1, 1, 1, 0);
//	half4 uv3 = uv.xyxy + uvoffset.xyxy * float4(1, -1, 0, -1);
//	half4 uv4 = uv.xyxy + uvoffset.xyxy * float4(-1, -1, -1, 0);
//	half4 col = SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv) * 0.15h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv1.xy) * 0.09h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv1.zw) * 0.12h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv2.xy) * 0.09h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv2.zw) * 0.12h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv3.xy) * 0.09h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv3.zw) * 0.12h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv4.xy) * 0.09h;
//	col += SAMPLE_TEXTURE2D(TEXTURE2D_ARGS(texName, sampler_texName), uv4.zw) * 0.12h;
//	return col;
//}

//带法线贴图的方向和位置信息
inline PosAndDirData InitPosData(half4 posOS, half3 normalOS, half4	tangentOS) {
	PosAndDirData data = (PosAndDirData)0;
	data.positionWS = TransformObjectToWorld(posOS.xyz);
	data.positionCS = TransformWorldToHClip(data.positionWS);
	data.normalWS = TransformObjectToWorldNormal(normalOS);
	data.viewWS = normalize(GetCameraPositionWS() - data.positionWS);
	real sign = tangentOS.w * GetOddNegativeScale();
	data.tangentWS = TransformObjectToWorldDir(tangentOS.xyz);
	data.bitangentWS = cross(data.tangentWS, data.normalWS) * sign;
	return data;
}

float4 GetShadowCoord(half4 positionCS, half3 positionWS)
{
#if SHADOWS_SCREEN
	return ComputeScreenPos(positionCS);
#else 
	return TransformWorldToShadowCoord(positionWS);
#endif
}

inline float Pow5(float val) {
	float  val1 = val * val;
	return val1 * val1 * val;
}

#endif