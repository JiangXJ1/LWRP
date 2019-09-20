#ifndef SELF_EFFECTS_H
#define SELF_EFFECTS_H

GLOBAL_CBUFFER_START(UnityStereoGlobals)
half _DepthFogStart;
half _DepthFogRange;
half _DepthFogDensity;
half _HeightFogStart;
half _HeightFogRange;
half _HeightFogDensity;
half4 sceneFogColor;
GLOBAL_CBUFFER_END
TEXTURE2D(_PlaneReflectMap);	SAMPLER(sampler_PlaneReflectMap);

float CalcFogFactor(half3 positionWS)
{
	half3 cameraWS = GetCameraPositionWS();
	half3 f3Distance = cameraWS - positionWS;
	half depthFog = min(max(0, length(f3Distance) - _DepthFogStart) / _DepthFogRange, 1) * _DepthFogDensity;

	half heightFog = min(max(0, cameraWS.y - positionWS.y) / _HeightFogRange, 1) * _HeightFogDensity;

	return max(depthFog, heightFog);
}

inline void ApplyFogInfo(inout half4 color, half fogFactor, half fogScale)
{
#ifdef USED_FOG
	fogScale = fogFactor * sceneFogColor.a * fogScale;
	color.a = lerp(color.a, 1.0h, fogScale);
	color.rgb = lerp(color.rgb, sceneFogColor.rgb, fogScale);
#endif
}

inline void ApplyEmmision(inout half4 color, half4 emmisioncol, half final) 
{
#ifdef OPEN_EMMISION
	half3 emmision = emmisioncol.rgb * final * color.rgb;
#ifdef EMMISION_TWEENED
	emmision *= abs(sin(emmisioncol.a * _Time.y * 10));
#endif
	color.rgb += emmision;
#endif
}

inline void ApplyPlannerReflection(inout half4 color, half4 positionSS, half4 reflectColor, half minCol, half reflectScale) {

	float2 uvScreen = positionSS.xy / positionSS.w;
	half4 refColor = SAMPLE_TEXTURE2D(_PlaneReflectMap, sampler_PlaneReflectMap, uvScreen);
	half maxcol = max(refColor.r, max(refColor.g, refColor.b));
	color = lerp(color, refColor * reflectColor, reflectScale * step(minCol, maxcol));
}

inline void ApplyPlannerReflection(inout half4 color, half4 positionSS, half4 reflectColor, half minCol, half reflectScale, float2 uvoffset) {

	float2 uvScreen = positionSS.xy / positionSS.w;
	half4 refColor = SAMPLE_TEXTURE2D(_PlaneReflectMap, sampler_PlaneReflectMap, uvScreen + uvoffset);
	half maxcol = max(refColor.r, max(refColor.g, refColor.b));
	color = lerp(color, refColor * reflectColor, reflectScale * step(minCol, maxcol));
}

inline void ApplyRim(inout half4 color, half4 rimColor, half3 N, half3 V, half3 newDir, half speed) 
{
	float scale = pow(1.0f - saturate(dot(N, V)), (1.0f - rimColor.a) * 10.0f + 1);
#ifdef RIM_DIR_RESET
	newDir = normalize(newDir);
	scale *= saturate(dot(N, newDir));
#endif
	rimColor.rgb *= scale;
	rimColor.rgb *= abs(cos(speed * _Time.y));
	color.rgb += rimColor.rgb;
}




#endif