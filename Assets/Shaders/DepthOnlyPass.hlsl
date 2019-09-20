#ifndef DEPTH_ONLY_PASS
#define DEPTH_ONLY_PASS
#include "Library/lighting.hlsl"

struct Attributes
{
    float4 position     : POSITION;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
#ifdef _ALPHATEST_ON
    float2 uv           : TEXCOORD0;
#endif
    float4 positionCS   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

#ifdef _ALPHATEST_ON
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
#endif
    output.positionCS = TransformObjectToHClip(input.position.xyz);
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
#ifdef _ALPHATEST_ON
	half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
	col *= _BaseColor;
	clip(col.a - _Cutoff - 0.01f);
#endif
    return 0;
}
#endif
