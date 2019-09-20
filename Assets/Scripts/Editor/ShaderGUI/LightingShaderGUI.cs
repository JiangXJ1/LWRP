using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine.Rendering;

public class LightingShaderGUI : IBaseShaderGUI
{
    public enum LightingMode
    {
        BRDF,
        BlinPhong,
        BlinPhongAniso,
        //OnlyGI,
        Unlit
    }
    public enum EffectType
    {
        Bloom = 1,//辉光
        RimLight = 2,//边缘光
        ReceiveFog = 4,//接收雾效
    }


    public override void OnSetupRenderType()
    {
        SetKeywordStateWithFloatValue("_SPECULARHIGHLIGHTS_OFF", "_SpecularLightOff");

    }

    public override void OnDrawRenderType()
    {
    }

    bool CheckShadowShow(float val)
    {
        if (val == 0)
            return false;
        var lightMode = (LightingMode)FindProperty("_LightingType").floatValue;
        if (lightMode != LightingMode.Unlit)// && lightMode != LightingMode.OnlyGI)
        {
            var renderType = (RenderType)FindProperty("_RenderType").floatValue;
            if (renderType == RenderType.Opaque)
            {
                return true;
            }
        }
        return false;
    }

    public override void OnSetupMaterialPropertys()
    {
        SetKeywordStateWithFloatValue("RECEIVE_SHADOWS", "_ReceiveShadow", CheckShadowShow);

        var lightProp = FindProperty("_LightingType");
        var lightMode = (LightingMode)lightProp.floatValue;
        
        material.DisableKeyword("LIGHT_BRDF");
        material.DisableKeyword("LIGHT_UNLIT");
        material.DisableKeyword("LIGHT_ONLYGI");
        material.DisableKeyword("LIGHT_PHONG");
        material.DisableKeyword("LIGHT_ANISO");

        var offsetQueue = FindProperty("_QueueOffset");
        offsetQueue.floatValue = 0;
        switch (lightMode)
        {
            case LightingMode.BRDF:
                offsetQueue.floatValue += 8;
                material.EnableKeyword("LIGHT_BRDF");
                break;
            case LightingMode.BlinPhong:
                offsetQueue.floatValue += 4;
                material.EnableKeyword("LIGHT_PHONG");
                break;
            case LightingMode.BlinPhongAniso:
                offsetQueue.floatValue += 6;
                material.EnableKeyword("LIGHT_ANISO");
                break;
            //case LightingMode.OnlyGI:
            //    offsetQueue.floatValue += 2;
            //    material.EnableKeyword("LIGHT_ONLYGI");
            //    break;
            case LightingMode.Unlit:
                material.EnableKeyword("LIGHT_UNLIT");
                break;
        }


        SetKeywordStateWithFloatValue("OPEN_EMMISION", "_EmmisionType", (val) => {
            return val > 0;
        });

        SetKeywordStateWithFloatValue("EMMISION_TWEENED", "_EmmisionType", (val) => {
            return val == 2;
        });
    }

    public override void OnDrawShaderPropertys()
    {
        materialEditor.TexturePropertySingleLine(new GUIContent("控制图", "r 金属度 g 光滑度 b 自发光"), FindProperty("_FinalMap"));
        EditorGUI.indentLevel++;
        EditorGUILayout.LabelField(new GUIContent("通道作用:r 金属度 g 光滑度 b 自发光"));
        EditorGUI.indentLevel--;
        EditorGUI.BeginChangeCheck();
        float _Metalness = materialEditor.RangeProperty(FindProperty("_Metalness"), "金属度");
        float _Roughness = materialEditor.RangeProperty(FindProperty("_Roughness"), "粗糙度");
        Color specColor = materialEditor.ColorProperty(FindProperty("_SpecularColor"), "高光颜色");
        if (EditorGUI.EndChangeCheck())
        {
            material.SetFloat("_Metalness", _Metalness);
            material.SetFloat("_Roughness", _Roughness);
            material.SetColor("_SpecularColor", specColor);            
        }
        
        var emmisionType = FindProperty("_EmmisionType");
        bool hasEmmision = emmisionType.floatValue > 0;
        bool hasEmmisionTween = emmisionType.floatValue == 2;
        EditorGUI.BeginChangeCheck();
        hasEmmision = EditorGUILayout.Toggle(new GUIContent("开启自发光"), hasEmmision);
        if (hasEmmision)
        {
            hasEmmisionTween = EditorGUILayout.Toggle(new GUIContent("自发光闪烁"), hasEmmisionTween);
        }
        if (EditorGUI.EndChangeCheck())
        {
            if (!hasEmmision)
            {
                emmisionType.floatValue = 0;
            }
            else
            {
                emmisionType.floatValue = hasEmmisionTween ? 2 : 1;
            }
        }

        if (hasEmmision)
        {
            EditorGUI.BeginChangeCheck();
            var emmisionColorProperty = FindProperty("_EmissionColor");
            Color emmisionColor = materialEditor.ColorProperty(emmisionColorProperty, "自发光");
            if (EditorGUI.EndChangeCheck())
            {
                emmisionColorProperty.colorValue = emmisionColor;
            }
        }


        var lightProp = FindProperty("_LightingType");
        DoPopup(new GUIContent("光照算法"), lightProp, Enum.GetNames(typeof(LightingMode)));
        var lightMode = (LightingMode)lightProp.floatValue;
        if(lightMode != LightingMode.Unlit)// && lightMode != LightingMode.OnlyGI)
        {
            EditorGUI.indentLevel++;
            var receiveShadowProp = FindProperty("_ReceiveShadow");
            var renderType = RenderType.Transparent;
            var renderTypeProp = FindProperty("_RenderType");
            if (renderTypeProp != null)
            {
                renderType = (RenderType)renderTypeProp.floatValue;
            }

            if (receiveShadowProp != null && renderType == RenderType.Opaque)
            {
                EditorGUI.BeginChangeCheck();
                var receiveShadowEnable = EditorGUILayout.Toggle(new GUIContent("接收实时阴影"), receiveShadowProp.floatValue == 1);
                if (EditorGUI.EndChangeCheck())
                {
                    receiveShadowProp.floatValue = receiveShadowEnable ? 1 : 0;
                }
            }
            EditorGUI.indentLevel--;
        }

        if (lightMode == LightingMode.BlinPhong || lightMode == LightingMode.BlinPhongAniso)
        {
            EditorGUI.indentLevel++;
            EditorGUI.BeginChangeCheck();

            var sepcTypeProp = FindProperty("_SpecularType");
            if (sepcTypeProp != null)
            {
                DoPopup(new GUIContent("高光方式"), sepcTypeProp, Enum.GetNames(typeof(SpecularType)));
            }

            if (lightMode == LightingMode.BlinPhongAniso)
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("各向异性贴图"), FindProperty("_AnisoMap"));
                EditorGUI.indentLevel++;
                materialEditor.RangeProperty(FindProperty("_AnisoOffset1"), "各向异性偏移x");
                materialEditor.RangeProperty(FindProperty("_AnisoOffset2"), "各向异性偏移y");
                EditorGUI.indentLevel--;
            }
            if (EditorGUI.EndChangeCheck())
            {
                var specType = (SpecularType)(int)sepcTypeProp.floatValue;
                SetKeyWordState("SPECULAR_ADD", specType == IBaseShaderGUI.SpecularType.Additional);
                SetKeyWordState("SPECULAR_DEFAULT", specType == IBaseShaderGUI.SpecularType.Default);
                SetKeyWordState("SPECULAR_OFF", specType == IBaseShaderGUI.SpecularType.CloseSpecular);
            }
            EditorGUI.indentLevel--;
        }
        else
        {
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(new GUIContent("环境图(Matcap)"), FindProperty("_ReflectMatCap"), FindProperty("_ReflectionCol"));
            EditorGUI.indentLevel--;
        }

    }

    public override void OnSetupEffectValues()
    {
        var efType = (int)FindProperty("_EffectType").floatValue;
        bool hasBloom = (efType & (int)EffectType.Bloom) > 0;
        bool hasRimlight = (efType & (int)EffectType.RimLight) > 0;
        bool hasFog = (efType & (int)EffectType.ReceiveFog) > 0;
        SetKeyWordState("OPEN_BLOOM", hasBloom);
        SetKeyWordState("USED_FOG", hasFog);

        SetKeyWordState("OPEN_RIM", hasRimlight);

        var rimLightProp = FindProperty("_RimLightInfo");
        bool rimDirReset = rimLightProp.floatValue == 1;
        SetKeyWordState("RIM_DIR_RESET", hasRimlight && rimDirReset);

        SetKeywordStateWithTextureValue("USED_RIMFINAL", "_RimFinal"); 
    }

    bool DrawRimLightInfo(bool hasRimlight)
    {
        hasRimlight = EditorGUILayout.Toggle(new GUIContent("开启边缘光"), hasRimlight);
        if (hasRimlight)
        {
            EditorGUI.indentLevel++;
            EditorGUI.BeginChangeCheck();
            
            var rimColorProp = FindProperty("_RimColor");
            materialEditor.ColorProperty(rimColorProp, "边缘光颜色");

            var rimLightProp = FindProperty("_RimLightInfo");
            bool rimDirReset = rimLightProp.floatValue == 1;
            materialEditor.RangeProperty(FindProperty("_RimTweenSpeed"), "闪烁速度");
            rimDirReset = EditorGUILayout.Toggle(new GUIContent("重设边缘光方向"), rimDirReset);
            if (rimDirReset)
            {
                EditorGUI.indentLevel++;
                materialEditor.VectorProperty(FindProperty("_RimDirection"), "边缘光方向");
                EditorGUI.indentLevel--;
            }

            if (EditorGUI.EndChangeCheck())
            {
                rimLightProp.floatValue = rimDirReset ? 1 : 0;
            }

            EditorGUI.indentLevel--;
        }
        
        return hasRimlight;
    }

    public override void OnDrawEffectValues()
    {
        var _EffectMask = FindProperty("_EffectMask");
        materialEditor.TexturePropertySingleLine(new GUIContent("特殊效果图", "r 辉光强度 g 平面反射强度 b 边缘光强度"), _EffectMask);
        EditorGUI.indentLevel++;
        EditorGUILayout.LabelField(new GUIContent("通道作用:r 辉光 g 平面反射 b 边缘光"));
        EditorGUI.indentLevel--;
        var effectTypeProp = FindProperty("_EffectType");
        var efType = (int)effectTypeProp.floatValue;
        bool hasBloom = (efType & (int)EffectType.Bloom) > 0;
        bool hasRimlight = (efType & (int)EffectType.RimLight) > 0;
        bool hasFog = (efType & (int)EffectType.ReceiveFog) > 0;
        int rEffectType = 0;

        EditorGUI.BeginChangeCheck();
        hasBloom = EditorGUILayout.Toggle(new GUIContent("开启辉光"), hasBloom);
        if (hasBloom)
        {
            EditorGUI.indentLevel++;
            materialEditor.RangeProperty(FindProperty("_BloomScale"), "辉光强度");
            EditorGUI.indentLevel--;
        }
        if (EditorGUI.EndChangeCheck())
        {
            material.SetShaderPassEnabled("BloomRender", hasBloom && FindProperty("_BloomScale").floatValue > 0);
        }

        materialEditor.ColorProperty(FindProperty("_PlaneReflectColor"), "平面反射颜色");

        hasRimlight = DrawRimLightInfo(hasRimlight);

        hasFog = EditorGUILayout.Toggle(new GUIContent("接收雾效"), hasFog);
        if (hasFog)
        {
            EditorGUI.indentLevel++;
            materialEditor.RangeProperty(FindProperty("_FogScale"), "雾效权重");
            EditorGUI.indentLevel--;
        }


        rEffectType |= (hasBloom ? (int)EffectType.Bloom : 0);
        rEffectType |= (hasRimlight ? (int)EffectType.RimLight : 0);
        rEffectType |= (hasFog ? (int)EffectType.ReceiveFog : 0);

        effectTypeProp.floatValue = rEffectType;
    }
}