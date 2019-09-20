// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "IShaders/Lighting" {
Properties {
	[MainTexture] _BaseMap ("固有色贴图", 2D) = "white" {}
	_BaseColor("基础颜色", Color) = (1,1,1,1)
	_BumpMap("法线贴图", 2D) = "bump" {}
	_BumpScale("辉光强度缩放", Float) = 1

	_AnisoMap("各向异性贴图", 2D) = "white" {}
	_AnisoOffset1("各向异性参数1", Range(0, 1)) = 1
	_AnisoOffset2("各向异性参数2", Range(0, 1)) = 1

	_ReflectMatCap ("反射贴图", 2D) = "white" {}
	_ReflectionCol("反射颜色", Color) = (0.5,0.5,0.5,1)

	_Metalness("金属度", Range(0,1)) = 1
	_Roughness("粗糙度", Range(0,1)) = 1

	_FinalMap("控制图(r 金属度 g 光滑度 b 自发光)", 2D) = "white" {}
	_EmissionColor("自发光颜色", Color) = (1, 1, 1, 1)
	//自发光类型  0  无自发光 1 不变的自发光 2 自动闪烁的自发光(速度由颜色的Alpha值控制)
	[HideInInspector] _EmmisionType("_EmmisionType", Float) = 0.0

	_SpecularColor("高光颜色", Color) = (1, 1, 1, 1)

	_EffectMask("辉光及边缘光控制图(r 辉光 g 反射 b 边缘光)", 2D) = "white" {}
	_BloomScale("辉光强度缩放", Range(0,1)) = 1

	_RimColor("边缘光颜色", Color) = (1,1,1,1)
	_RimTweenSpeed("边缘光闪烁速度", Range(0,10)) = 0
	_RimDirection("边缘光方向", Vector) = (0,1,0,1) 

	_FogScale("Fog Scale", Range(0,1)) = 1.0

	_Cutoff("Alpha剔除", Range(0,1)) = 0

	[HideInInspector] _PlaneReflectMap("平面反射贴图", 2D) = "bump" {}
	[HideInInspector] _PlaneReflectOffsetX("平面反射颜色", Float) = 0
	[HideInInspector] _PlaneReflectOffsetY("平面反射颜色", Float) = 0
	_PlaneReflectColor("平面反射颜色", Color) = (1,1,1,1)

	[HideInInspector] _SrcBlend("__src", Float) = 1.0
	[HideInInspector] _DstBlend("__dst", Float) = 0.0
	[HideInInspector] _ZWrite("__zw", Float) = 1.0
	[HideInInspector] _Cull("__cull", Float) = 2.0
	// Editmode props
	[HideInInspector] _AlphaClip("__AlphaClip", Float) = 0.0
	[HideInInspector] _Blend("__blend", Float) = 0.0
	[HideInInspector] _Queue("Queue", Float) = 0.0
	[HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
	[HideInInspector] _RenderType("Render Type", Float) = 0.0
	[HideInInspector] _SpecularType("Light Type", Float) = 0.0
	[HideInInspector] _ReceiveShadow("Receive Shadow", Float) = 0.0
	[HideInInspector] _LightingType("__LightingType", Float) = 0.0
	[HideInInspector] _EffectType("__EffectType", Float) = 0.0
	//0 普通边缘光  1 闪烁边缘光 2 重定向边缘光方向 3 闪烁的重定向
	[HideInInspector] _RimLightInfo("_RimLightInfo", Float) = 0
}

SubShader {
	LOD 100
	Tags{"RenderType" = "Opaque" "RenderPipeline" = "LightweightPipeline" "IgnoreProjector" = "True"}

		Pass
		{
			Name "TransparentPreDepth"
			Tags{"LightMode" = "TransparentPreDepth"}

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

		Pass
		{
			Name "ForwardLit"
			Tags{"LightMode" = "LightweightForward"}

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]
			ColorMask RGB
			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment fragDefault
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0
			#pragma multi_compile_instancing

			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature RENDER_TRANSPARENT
			#pragma shader_feature SPECULAR_DEFAULT SPECULAR_ADD SPECULAR_OFF 
			#pragma shader_feature LIGHT_BRDF LIGHT_PHONG LIGHT_ANISO LIGHT_UNLIT
			//是否开启自发光
			#pragma shader_feature OPEN_EMMISION
			//自发光闪烁
			#pragma shader_feature EMMISION_TWEENED
			//是否开启辉光
			#pragma shader_feature OPEN_BLOOM

			//是否开启边缘光
			#pragma shader_feature OPEN_RIM
			//是否重置边缘光方向
			#pragma shader_feature RIM_DIR_RESET
			#pragma shader_feature RECEIVE_SHADOWS

			//是否使用雾效
			#pragma shader_feature USED_FOG
			//是否开启边缘光
			#pragma shader_feature USED_BUMPMAP
			#pragma shader_feature BUMPMAP_SCALE

			//反射
			#pragma multi_compile _ USING_REFLECTION

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

			#pragma multi_compile _ _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _SHADOWS_SOFT

	
		
			#include "Library/lighting.hlsl"

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

		Pass
		{
			Name "BloomRender"
			Tags{"LightMode" = "BloomRender"}

			ZWrite Off
			ColorMask A
			Cull[_Cull]
			Blend One Zero
			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex BloomRenderVertex
			#pragma fragment BloomRenderFragment

			// -------------------------------------
			// Material Keywords
			#pragma multi_compile _ OPEN_BLOOM
			#pragma multi_compile _ _ALPHATEST_ON
			

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing

			#include "BloomRenderPass.hlsl"
			ENDHLSL
		}
	}

	FallBack "Hidden/InternalErrorShader"
	CustomEditor "LightingShaderGUI"
}
