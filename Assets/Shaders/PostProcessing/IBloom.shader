Shader "Hidden/PostProcessing/IBloom"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Sampling.hlsl"

	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
	TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);

	float4 _BloomAddColor;
	float _BloomColorScale;
	float _BloomMinColor;
	float4 _MainTex_TexelSize;

	half4 fragPrefilter(VaryingsDefault i) : SV_Target
	{
		half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
		half stepVal = step(0.01h, col.a) * step(col.a, 0.99h) * _BloomAddColor.a;
		half dot = max(col.r ,max( col.g ,col.b));
		return half4(stepVal * col.rgb * col.a * _BloomColorScale * _BloomAddColor.rgb * step(_BloomMinColor, dot), col.a);
		//return half4(stepVal * col.rgb * col.a * _BloomColorScale * _BloomAddColor.rgb, col.a);
	}


	half4 FragDownsample(VaryingsDefault i) : SV_Target
	{
		half4 color = DownsampleBox4Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy);
		return color;
	}

	half4 FragUpsample(VaryingsDefault i) : SV_Target
	{
		half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
		half4 col1 = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, i.texcoord);
		return max(col, col1);
	}

	half4 FragBlit(VaryingsDefault i) : SV_Target
	{
		half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
		half4 col1 = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, i.texcoord);
		col.rgb += col1.rgb;
		col.rgb = min(col.rgb, 1);
		return col;
	}

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0: Prefilter 13 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment fragPrefilter

            ENDHLSL
        }

		// 1: DownSample
		Pass
		{
			HLSLPROGRAM

			#pragma vertex VertDefault
			#pragma fragment FragDownsample

			ENDHLSL
		}

		// 2: UpSample
		Pass
		{
			HLSLPROGRAM

			#pragma vertex VertDefault
			#pragma fragment FragUpsample

			ENDHLSL
		}

		// 3: Blit
		Pass
		{
			HLSLPROGRAM

			#pragma vertex VertDefault
			#pragma fragment FragBlit

			ENDHLSL
		}
    }
}
