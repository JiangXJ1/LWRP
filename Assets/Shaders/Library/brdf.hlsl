#ifndef SHADER_LIB_PBR_NEW
#define SHADER_LIB_PBR_NEW
#include "base.hlsl"


struct MYBRDFInput {
	//转换到世界空间进行计算
	half3 N;
	half3 V;
	half3 gi;
	half metallic;
	half roughness;
	half3 reflectColor;
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	half4 shadowCoord;
#endif

#ifdef _ADDITIONAL_LIGHTS
	half3 positionWS;
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	half3 vertexLighting;
#endif
};

struct MYBRDFData {
	half NdotV;
	half metallic;
	half roughness;
	half smoothness;
	half roughness2;
	half grazingTerm;
	half3 diffuse;
	half3 specular;
	half normalizationTerm;
	half roughness2MinusOne;
};

inline void InitMYBRDFData(in MYBRDFInput input, inout MYBRDFData outData, half3 baseColor, half4 specColor) {

	half oneMinusReflectivity = OneMinusReflectivityMetallic(input.metallic);
	half reflectivity = 1.0 - oneMinusReflectivity;

	outData.metallic = input.metallic;
	outData.roughness = input.roughness;
	outData.smoothness = 1 - input.roughness;
	outData.roughness2 = input.roughness * input.roughness;
	outData.NdotV = saturate(dot(input.N, input.V));
	outData.diffuse = baseColor * lerp(1, input.reflectColor, reflectivity) * lerp(0.3h, 1, oneMinusReflectivity);
	outData.specular = lerp(kDieletricSpec.rgb, baseColor * specColor.rgb, outData.metallic * specColor.a);
	outData.grazingTerm = saturate(outData.smoothness + reflectivity);
	outData.normalizationTerm = outData.roughness * 4.0h + 2.0h;
	outData.roughness2MinusOne = outData.roughness2 - 1.0h;
}

inline half3 CalcLightPBR(in MYBRDFInput input, in MYBRDFData data, Light light)
{
	half3 L = light.direction;
	half3 N = input.N;
	half NdotL = saturate(dot(N, L));
	float lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
	half3 lightColor = light.color * lightAttenuation * NdotL;

#ifndef _SPECULARHIGHLIGHTS_OFF
	half3 H = normalize(L + input.V);
	half3 V = input.V;
	half NdotV = data.NdotV;
	half NdotH = saturate(dot(N, H));
	half LdotH = saturate(dot(L, H));
	half VdotH = saturate(dot(V, H));

	half3 diffuse = data.diffuse;
	half3 specular = data.specular;

    half d = NdotH * NdotH * data.roughness2MinusOne + 1.00001h;

    half LdotH2 = LdotH * LdotH;
    half specularTerm = data.roughness2 / ((d * d) * max(0.1h, LdotH2) * data.normalizationTerm);

#if defined (SHADER_API_MOBILE)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif
    half3 color = specularTerm * specular + diffuse;
    return color * lightColor;
#else
	return (data.diffuse + data.specular) * lightColor;
#endif
}

half3 EnvironmentBRDF(MYBRDFData pbrData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
	half3 c = indirectDiffuse * pbrData.diffuse;
	float surfaceReduction = 1.0f / (pbrData.roughness2 + 1.0f);
	c += surfaceReduction * indirectSpecular * lerp(pbrData.specular, pbrData.grazingTerm, fresnelTerm);
	return c;
}

half3 GlobalIllumination(MYBRDFData pbrData, half3 bakedGI, half NdotV, half3 N, half3 V)
{
	//half3 reflectVector = reflect(-V, N);
	half fresnelTerm = Pow4(1.0 - NdotV);

	half3 indirectDiffuse = bakedGI;
	half3 indirectSpecular = _GlossyEnvironmentColor.rgb;// GlossyEnvironmentReflection(reflectVector, pbrData.roughness, 1);

	return EnvironmentBRDF(pbrData, indirectDiffuse, indirectSpecular, fresnelTerm);
}

inline void InitBRDFInput(inout MYBRDFInput outData,
	half3 N, half3 V, half3 gi, half3 reflectColor, half3 vertexLighting,
	half metallic, half roughness, half3 positionWS)
{
	//转换到世界空间进行计算
	outData.N = N;
	outData.V = V;
	outData.gi = gi;

	outData.metallic = metallic;
	//粗糙度
	outData.roughness = roughness;

	outData.reflectColor = reflectColor;
#ifdef _ADDITIONAL_LIGHTS
	outData.positionWS = positionWS;
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	outData.vertexLighting = vertexLighting;
#endif
}

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
inline void InitBRDFInput(inout MYBRDFInput outData, 
	half3 N, half3 V, half3 gi, half3 reflectColor, half3 vertexLighting, 
	half metallic, half roughness, half3 positionWS, half4 shadowCoord)
{
	InitBRDFInput(outData, N, V, gi, reflectColor, vertexLighting, metallic, roughness, positionWS);
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	outData.shadowCoord = shadowCoord;
#endif
}
#endif

inline half3 FragmentBRDF(MYBRDFInput input, in half3 baseColor, in half4 specColor)
{
	MYBRDFData data = (MYBRDFData)0;
	InitMYBRDFData(input, data, baseColor, specColor);
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
	Light mainLight = GetMainLight(input.shadowCoord);
#else
	Light mainLight = GetMainLight();
#endif

	MixLightAndGI(mainLight, input.N, input.gi, half4(0, 0, 0, 1));

	half3 color = GlobalIllumination(data, input.gi.rgb, data.NdotV, input.N, input.V);
	color += CalcLightPBR(input, data, mainLight);
#ifdef _ADDITIONAL_LIGHTS
	int pixelLightCount = GetAdditionalLightsCount();
	for (int idx = 0; idx < pixelLightCount; ++idx)
	{
		Light light = GetAdditionalLight(idx, input.positionWS);
		color += CalcLightPBR(input, data, light);
	}
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	color += input.vertexLighting * data.diffuse;
#endif

	return color;
}

#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
#define LightingBRDF(outcol,col,N,V,gi,_SpecularColor,reflectColor,vertexLighting,final,_Metalness,_Roughness, positionWS, shadowCoord) \
	MYBRDFInput input = (MYBRDFInput)0;\
	half metallic = _Metalness * final.r;\
	half roughness = _Roughness * final.g;\
	InitBRDFInput(input, N, V, gi, reflectColor, vertexLighting, metallic, roughness, positionWS, shadowCoord);\
	outcol=FragmentBRDF(input, col.rgb, _SpecularColor);
#else
#define LightingBRDF(outcol,col,N,V,gi,_SpecularColor,reflectColor,vertexLighting,final,_Metalness,_Roughness, positionWS, shadowCoord) \
	MYBRDFInput input = (MYBRDFInput)0;\
	half metallic = _Metalness * final.r;\
	half roughness = _Roughness * final.g;\
	InitBRDFInput(input, N, V, gi, reflectColor, vertexLighting, metallic, roughness, positionWS);\
	outcol=FragmentBRDF(input, col.rgb, _SpecularColor);
#endif


#endif