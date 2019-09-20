// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "IShaders/SSSS" {
Properties {
	[MainTexture] _BaseMap ("固有色贴图", 2D) = "white" {}
	_BaseColor("基础颜色", Color) = (1,1,1,1)
	_BumpMap("法线贴图", 2D) = "bump" {}
	_FogScale("Fog Scale", Range(0, 1)) = 1.0

	_FinalMap("控制图(r 曲率 g 光滑度 b 自发光)", 2D) = "white" {}
	_SSSLUTMap("SSSLUT", 2D) = "white" {}
	_KelementLUTMap("KelementLUT", 2D) = "white" {}
	_SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
	_SpecularScale("高光缩放", Range(0.1,10)) = 1

	// Editmode props
	[HideInInspector] _SpecularType("Light Type", Float) = 0.0
}

SubShader {
	LOD 100
	Tags{"RenderType" = "Opaque" "RenderPipeline" = "LightweightPipeline" "IgnoreProjector" = "True"}

		Pass
		{
			Name "ForwardLit"
			Tags{"LightMode" = "LightweightForward"}
			ColorMask RGB
			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment fragSkin
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0
			#pragma multi_compile_instancing

			#pragma shader_feature _ _ALPHATEST_ON
			#pragma shader_feature _ RECEIVE_SHADOWS
			#pragma shader_feature SPECULAR_DEFAULT SPECULAR_ADD SPECULAR_OFF 

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS

			#pragma multi_compile _ _ADDITIONAL_LIGHTS

			#pragma multi_compile _ _SHADOWS_SOFT 

			//是否使用边缘光过渡图
			#pragma multi_compile _ USED_FOG


			#include "Library/skinlighting.hlsl"
			
			ENDHLSL

		}

		Pass
		{
			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual
			Cull[_Cull]

			HLSLPROGRAM
		// Required to compile gles 2.0 with standard srp library
		#pragma prefer_hlslcc gles
		#pragma exclude_renderers d3d11_9x
		#pragma target 2.0

		// -------------------------------------
		// Material Keywords
		#pragma multi_compile _ _ALPHATEST_ON

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing

		#pragma vertex ShadowPassVertex
		#pragma fragment ShadowPassFragment

		#include "ShadowCasterPass.hlsl"
		ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags{"LightMode" = "DepthOnly"}

			ZWrite On
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
		// Required to compile gles 2.0 with standard srp library
		#pragma prefer_hlslcc gles
		#pragma exclude_renderers d3d11_9x
		#pragma target 2.0

		#pragma vertex DepthOnlyVertex
		#pragma fragment DepthOnlyFragment

		// -------------------------------------
		// Material Keywords
		#pragma multi_compile _ _ALPHATEST_ON

		//--------------------------------------
		// GPU Instancing
		#pragma multi_compile_instancing

		#include "DepthOnlyPass.hlsl"
		ENDHLSL
		}
	}
	FallBack "Hidden/InternalErrorShader"
	CustomEditor "SSSSLightingGUI"
}
