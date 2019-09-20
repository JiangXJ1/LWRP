// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "IShaders/TerrainLighting" {
Properties {
	[MainTexture] _BaseMap ("固有色贴图", 2D) = "white" {}
	_Control("Control(RGBA)", 2D) = "white"{}

	_SplatMap0("Layer 1", 2D) = "white" {}
	_BumpMap0("Bump 1", 2D) = "bump" {}
	_BaseColor0("Base Color 1", Color) = (1,1,1,1)
	_SpecColor0("Spec Color 1", Color) = (1,1,1,1)


	_SplatMap1("Layer 2", 2D) = "white" {}
	_BumpMap1("Bump 2", 2D) = "bump" {}
	_BaseColor1("Base Color 2", Color) = (1,1,1,1)
	_SpecColor1("Spec Color 2", Color) = (1,1,1,1)

	_SplatMap2("Layer 3", 2D) = "white" {}
	_BumpMap2("Bump 3", 2D) = "bump" {}
	_BaseColor2("Base Color 3", Color) = (1,1,1,1)
	_SpecColor2("Spec Color 3", Color) = (1,1,1,1)

	_SplatMap3("Layer 4", 2D) = "white" {}
	_BumpMap3("Bump 4", 2D) = "bump" {}
	_BaseColor3("Base Color 4", Color) = (1,1,1,1)
	_SpecColor3("Spec Color 4", Color) = (1,1,1,1)

	_FogScale("fog scale", Range(0, 1)) = 1
	
	_SpecType("specular type", Float) = 1
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
			#pragma fragment frag
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0
			#pragma multi_compile_instancing

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
		

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

			#pragma multi_compile _ _ADDITIONAL_LIGHTS
		
			//#pragma multi_compile _ENVIRONMENTREFLECTIONS_OFF _ENVIRONMENTREFLECTIONS_ON
			#pragma multi_compile _ _SHADOWS_SOFT

			//是否使用雾效
			#pragma shader_feature _ USED_FOG

			#pragma shader_feature _ USED_SPLAT0
			#pragma shader_feature _ USED_SPLAT1
			#pragma shader_feature _ USED_SPLAT2
			#pragma shader_feature _ USED_SPLAT3
			
			#pragma multi_compile SPECULAR_DEFAULT SPECULAR_ADD SPECULAR_OFF 
	

			#include "TerrainLightPass.hlsl"

			

			ENDHLSL

		}

		Pass
		{
			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual

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
	CustomEditor "TerrainLightingGUI"
}
