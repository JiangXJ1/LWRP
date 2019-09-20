#ifndef BLOOM_RENDER_PASS
#define BLOOM_RENDER_PASS
#include "Library/lighting.hlsl"

struct Attributes
{
    float4 position     : POSITION;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings BloomRenderVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = TransformObjectToHClip(input.position.xyz);
    return output;
}

half4 BloomRenderFragment(Varyings input) : SV_TARGET
{
#ifdef _ALPHATEST_ON
	half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
	col *= _BaseColor;
	clip(col.a - _Cutoff - 0.01f);
#endif

#ifdef OPEN_BLOOM
	half3 effFinal = SAMPLE_TEXTURE2D(_EffectMask, sampler_EffectMask, input.uv).rgb;
	return half4(0, 0, 0, (effFinal.r * _BloomScale) * 0.98h);
#else
	return half4(0, 0, 0, 1);
#endif
}
#endif
