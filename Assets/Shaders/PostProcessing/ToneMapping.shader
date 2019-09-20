Shader "Hidden/PostProcessing/ToneMapping"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Sampling.hlsl"

	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
	float4 whitePoint;
	float4 blackPoint;

	float3 ACESToneMapping(float3 color)
	{
		const float adapted_A = 2.51f;
		const float adapted_B = 0.03f;
		const float adapted_C = 2.43f;
		const float adapted_D = 0.59f;
		const float adapted_E = 0.14f;
		float3 A = color * (adapted_A * color + adapted_B);
		float3 B = color * (adapted_C * color + adapted_D) + adapted_E;
		return (color * (adapted_A * color + adapted_B)) / (color * (adapted_C * color + adapted_D) + adapted_E);
	}

	float3 ColorGrading(float3 color) 
	{
		color = max(0, color - blackPoint.rgb);
		color = color / (whitePoint.rgb - blackPoint.rgb);
		return color;
	}

	half4 frag(VaryingsDefault i) : SV_Target
	{
		half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
#ifdef OPEN_COLORGRADING
		col.rgb = ColorGrading(col.rgb);
#endif
#ifdef OPEN_TONEMAPPING
		col.rgb = ACESToneMapping(col.rgb);
#endif
		return col;
	}

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment frag
				#pragma multi_compile _ OPEN_TONEMAPPING
				#pragma multi_compile _ OPEN_COLORGRADING

            ENDHLSL
        }

    }
}
