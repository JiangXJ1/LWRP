using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine.Rendering;

public class IBaseShaderGUI : ShaderGUI
{
    #region enums
    public enum LightType
    {
        Unlit,
        Diffuse,
        BlinPhong,
        BRDF
    }

    public enum RenderType
    {
        Opaque,
        Transparent
    }

    public enum BlendMode
    {
        Alpha,   // Old school alpha-blending mode, fresnel does not affect amount of transparency
        Premultiply, // Physically plausible transparency mode, implemented as alpha pre-multiply
        Additive,
        Multiply
    }


    public enum RenderFace
    {
        //正面渲染
        Front = 2,
        //背面渲染
        Back = 1,
        //双面渲染
        Both = 0
    }

    public enum SpecularType
    {
        Default,
        Additional,
        CloseSpecular
    }
    #endregion


    protected class Styles
    {
        // Catergories
        public static readonly GUIContent renderTypeSetting = new GUIContent("渲染设置");
        
        public static readonly GUIContent materialPropertySetting = new GUIContent("材质设置");

        public static readonly GUIContent effectPropertySetting = new GUIContent("特殊效果设置");
    }


    SavedBoolValue showRenderTypeSetting;

    SavedBoolValue showPropertySetting;

    SavedBoolValue showEffectSetting;

    public static int ColorMaskRGB = (int)(ColorWriteMask.Red | ColorWriteMask.Green | ColorWriteMask.Blue);
    public static int COlorMaskRGBA = (int)ColorWriteMask.All;

    private bool isFirstOpen = true;
    public MaterialEditor materialEditor;
    public Material material;
    public Dictionary<string, MaterialProperty> dicAllProperties;

    private void InitProperties(MaterialEditor editor, MaterialProperty[] properties)
    {
        materialEditor = editor;
        material = editor.target as Material;
        if (material == null)
            return;
        isFirstOpen = false;
        showRenderTypeSetting = new SavedBoolValue("rendertype settings:" + material.shader.name, true);
        showPropertySetting = new SavedBoolValue("properties settings:" + material.shader.name, true);
        showEffectSetting = new SavedBoolValue("render effects settings:" + material.shader.name, true);
        dicAllProperties = new Dictionary<string, MaterialProperty>();
        for(int i = 0; i < properties.Length; ++i)
        {
            var prop = properties[i];
            dicAllProperties.Add(prop.name, prop);
        }
    }

    public MaterialProperty FindProperty(string propName)
    {
        if (dicAllProperties == null)
            return null;
        MaterialProperty property;
        if(dicAllProperties.TryGetValue(propName, out property))
        {
            return property;
        }
        return null;
    }


    public void SetKeyWordState(string key, bool value)
    {
        if (value && !material.IsKeywordEnabled(key))
            material.EnableKeyword(key);
        if (!value && material.IsKeywordEnabled(key))
            material.DisableKeyword(key);
    }

    public void SetKeywordStateWithTextureValue(string key, string propName, bool reverse = false)
    {
        var prop = FindProperty(propName);
        bool value = prop != null && prop.textureValue != null;
        if (reverse)
            value = !value;
        SetKeyWordState(key, value);
    }

    public delegate bool CheckFloatValue(float fvalue);

    public void SetKeywordStateWithFloatValue(string key, string propName, CheckFloatValue checkFunc = null)
    {
        var prop = FindProperty(propName);
        bool value = false;
        if(checkFunc == null)
        {
            value = prop != null && prop.floatValue == 1;
        }
        else
        {
            value = prop != null && checkFunc(prop.floatValue);
        }
        SetKeyWordState(key, value);
    }

    public virtual void OnSetupRenderType()
    {

    }

    public void SetupRenderType()
    {
        var renderType = RenderType.Transparent;
        var renderTypeProp = FindProperty("_RenderType");
        if (renderTypeProp != null)
        {
            renderType = (RenderType)renderTypeProp.floatValue;
        }

        if (renderType == RenderType.Opaque)
        {
            bool alphaTestOn = FindProperty("_AlphaClip").floatValue == 1 && FindProperty("_Cutoff").floatValue > 0;
            SetKeyWordState("_ALPHATEST_ON", alphaTestOn);

            SetKeyWordState("RENDER_TRANSPARENT", false);
            material.SetFloat("_ZWrite", 1);
            material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
            FindProperty("_Queue").floatValue = (int)UnityEngine.Rendering.RenderQueue.Geometry;
            material.SetOverrideTag("RenderType", "Opaque");
            material.SetShaderPassEnabled("ShadowCaster", true);
            material.SetShaderPassEnabled("DepthOnly", true);
            material.SetShaderPassEnabled("TransparentPreDepth", false);
        }
        else
        {
            SetKeyWordState("RECEIVE_SHADOWS", false);
            BlendMode blendMode = (BlendMode)material.GetFloat("_Blend");
            // Specific Transparent Mode Settings
            switch (blendMode)
            {
                case BlendMode.Alpha:
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    break;
                case BlendMode.Premultiply:
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                    break;
                case BlendMode.Additive:
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    break;
                case BlendMode.Multiply:
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.DstColor);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.EnableKeyword("_ALPHAMODULATE_ON");
                    break;
            }

            bool alphaTestOn = FindProperty("_AlphaClip").floatValue == 1 && FindProperty("_Cutoff").floatValue < 1;
            SetKeyWordState("_ALPHATEST_ON", alphaTestOn);

            SetKeyWordState("RENDER_TRANSPARENT", true);
            material.SetInt("_ZWrite", 0);

            if (material.IsKeywordEnabled("_ALPHATEST_ON"))
            {
                FindProperty("_Queue").floatValue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                material.SetOverrideTag("RenderType", "TransparentCutout");
            }
            else
            {
                FindProperty("_Queue").floatValue = (int)RenderQueue.Transparent;
                material.SetOverrideTag("RenderType", "Transparent");
            }
            material.SetShaderPassEnabled("DepthOnly", alphaTestOn);
            material.SetShaderPassEnabled("ShadowCaster", false);
            material.SetShaderPassEnabled("TransparentPreDepth", alphaTestOn);
        }
        OnSetupRenderType();
    }

    public virtual void OnDrawRenderType()
    {

    }

    public virtual void DrawRenderType()
    {
        EditorGUI.BeginChangeCheck();
        var renderType = RenderType.Transparent;
        var renderTypeProp = FindProperty("_RenderType");
        if(renderTypeProp != null)
        {
            DoPopup(new GUIContent("物体类型", "Opaque为非透明物体, Transparent为透明物体"), renderTypeProp, Enum.GetNames(typeof(RenderType)));
            renderType = (RenderType)renderTypeProp.floatValue;
        }
        if(renderType == RenderType.Transparent)
        {
            var blendProp = FindProperty("_Blend");
            if(blendProp != null)
            {
                DoPopup(new GUIContent("颜色混合类型", "Alpha: 普通Alpha混合 Premultiply:AlphaAdd Additive: ColorAdd Multiply:直接覆盖"), blendProp, Enum.GetNames(typeof(BlendMode)));
            }
        }

        EditorGUI.BeginChangeCheck();
        var cullProp = FindProperty("_Cull");
        var culling = (RenderFace)cullProp.floatValue;
        culling = (RenderFace)EditorGUILayout.EnumPopup(new GUIContent("背面剔除", "Front 正常模式, Back 背面渲染, Both 双面渲染"), culling);
        if (EditorGUI.EndChangeCheck())
        {
            cullProp.floatValue = (float)culling;
            material.doubleSidedGI = (RenderFace)cullProp.floatValue != RenderFace.Front;
        }
        
        var alphaTestProp = FindProperty("_AlphaClip");
        if (alphaTestProp != null)
        {
            EditorGUI.BeginChangeCheck();
            var alphaClipEnabled = EditorGUILayout.Toggle(new GUIContent("开启Alpha剔除"), alphaTestProp.floatValue == 1);
            if (EditorGUI.EndChangeCheck())
            {
                alphaTestProp.floatValue = alphaClipEnabled ? 1 : 0;
            }
            if (alphaTestProp.floatValue == 1)
            {
                materialEditor.ShaderProperty(FindProperty("_Cutoff"), new GUIContent("Alpha裁剪值"), 1);
            }
        }

        OnDrawRenderType();

        if (EditorGUI.EndChangeCheck())
            SetupRenderType();
    }


    public virtual void OnSetupMaterialPropertys()
    {
        var offsetQueue = FindProperty("_QueueOffset");
        if (offsetQueue == null)
            return;
        offsetQueue.floatValue = 0;
    }

    public void SetupMaterialPropertys()
    {
        SetKeywordStateWithTextureValue("USED_BUMPMAP", "_BumpMap");
        SetKeywordStateWithFloatValue("USED_BUMPMAP", "_BumpScale", (x) => { return x != 1; });
        OnSetupMaterialPropertys();
    }
    public virtual void OnDrawShaderPropertys()
    {

    }

    public void DrawShaderPropertys()
    {
        EditorGUI.BeginChangeCheck();
        var baseMap = FindProperty("_BaseMap");
        var baseColor = FindProperty("_BaseColor");
        if(baseMap != null)
        {
            materialEditor.TexturePropertySingleLine(new GUIContent("主贴图"), baseMap, baseColor);
        }

        var bumpMap = FindProperty("_BumpMap");
        var bumpScale = FindProperty("_BumpScale");
        if(bumpMap != null)
        {
            materialEditor.TexturePropertySingleLine(new GUIContent("法线贴图"), bumpMap, bumpScale);
        }
        OnDrawShaderPropertys();
        if (EditorGUI.EndChangeCheck())
        {
            SetupMaterialPropertys();
        }
    }

    public virtual void OnSetupEffectValues()
    {

    }

    public void SetupEffectValues()
    {
        OnSetupEffectValues();
    }

    public virtual void OnDrawEffectValues()
    {
    }

    public void DrawEffectValues()
    {
        EditorGUI.BeginChangeCheck();
        OnDrawEffectValues();
        if (EditorGUI.EndChangeCheck())
        {
            SetupEffectValues();
        }
    }

    public void DrawShaderUI()
    {
        showRenderTypeSetting.value = EditorGUILayout.BeginFoldoutHeaderGroup(showRenderTypeSetting.value, Styles.renderTypeSetting);
        if(showRenderTypeSetting.value)
            DrawRenderType();
        EditorGUILayout.EndFoldoutHeaderGroup();
        showPropertySetting.value = EditorGUILayout.BeginFoldoutHeaderGroup(showPropertySetting.value, Styles.materialPropertySetting);
        if (showPropertySetting.value)
            DrawShaderPropertys();
        EditorGUILayout.EndFoldoutHeaderGroup();
        showEffectSetting.value = EditorGUILayout.BeginFoldoutHeaderGroup(showEffectSetting.value, Styles.effectPropertySetting);
        if (showEffectSetting.value)
            DrawEffectValues();
        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if(isFirstOpen)
            InitProperties(materialEditor, properties);
        EditorGUI.BeginChangeCheck();
        DrawShaderUI();
        if (EditorGUI.EndChangeCheck())
        {
            var offsetQueue = FindProperty("_QueueOffset");
            if (offsetQueue != null)
                material.renderQueue = (int)(FindProperty("_Queue").floatValue + offsetQueue.floatValue);
            else
                material.renderQueue = (int)FindProperty("_Queue").floatValue;
            if (material.IsKeywordEnabled("_ALPHATEST_ON"))
                material.renderQueue+=20;
        }
        material.enableInstancing = EditorGUILayout.Toggle(new GUIContent("GPU Instancing"), material.enableInstancing);
        EditorGUILayout.LabelField(new GUIContent("render queue:" + material.renderQueue));
    }
    #region HelperFunctions

    public static void TwoFloatSingleLine(GUIContent title, MaterialProperty prop1, GUIContent prop1Label,
        MaterialProperty prop2, GUIContent prop2Label, MaterialEditor materialEditor, float labelWidth = 30f)
    {
        EditorGUI.BeginChangeCheck();
        EditorGUI.showMixedValue = prop1.hasMixedValue || prop2.hasMixedValue;
        Rect rect = EditorGUILayout.GetControlRect();
        EditorGUI.PrefixLabel(rect, title);
        var indent = EditorGUI.indentLevel;
        var preLabelWidth = EditorGUIUtility.labelWidth;
        EditorGUI.indentLevel = 0;
        EditorGUIUtility.labelWidth = labelWidth;
        Rect propRect1 = new Rect(rect.x + preLabelWidth, rect.y,
            (rect.width - preLabelWidth) * 0.5f, EditorGUIUtility.singleLineHeight);
        var prop1val = EditorGUI.FloatField(propRect1, prop1Label, prop1.floatValue);

        Rect propRect2 = new Rect(propRect1.x + propRect1.width, rect.y,
            propRect1.width, EditorGUIUtility.singleLineHeight);
        var prop2val = EditorGUI.FloatField(propRect2, prop2Label, prop2.floatValue);

        EditorGUI.indentLevel = indent;
        EditorGUIUtility.labelWidth = preLabelWidth;

        if (EditorGUI.EndChangeCheck())
        {
            materialEditor.RegisterPropertyChangeUndo(title.text);
            prop1.floatValue = prop1val;
            prop2.floatValue = prop2val;
        }

        EditorGUI.showMixedValue = false;
    }

    public void DoPopup(GUIContent label, MaterialProperty property, string[] options)
    {
        DoPopup(label, property, options, materialEditor);
    }

    public static void DoPopup(GUIContent label, MaterialProperty property, string[] options, MaterialEditor materialEditor)
    {
        if (property == null)
            throw new ArgumentNullException("property");

        EditorGUI.showMixedValue = property.hasMixedValue;

        var mode = property.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = EditorGUILayout.Popup(label, (int)mode, options);
        if (EditorGUI.EndChangeCheck())
        {
            materialEditor.RegisterPropertyChangeUndo(label.text);
            property.floatValue = mode;
        }

        EditorGUI.showMixedValue = false;
    }

    // Helper to show texture and color properties
    public static Rect TextureColorProps(MaterialEditor materialEditor, GUIContent label, MaterialProperty textureProp, MaterialProperty colorProp, bool hdr = false)
    {
        Rect rect = EditorGUILayout.GetControlRect();
        EditorGUI.showMixedValue = textureProp.hasMixedValue;
        materialEditor.TexturePropertyMiniThumbnail(rect, textureProp, label.text, label.tooltip);
        EditorGUI.showMixedValue = false;

        if (colorProp != null)
        {
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = colorProp.hasMixedValue;
            int indentLevel = EditorGUI.indentLevel;
            EditorGUI.indentLevel = 0;
            Rect rectAfterLabel = new Rect(rect.x + EditorGUIUtility.labelWidth, rect.y,
                EditorGUIUtility.fieldWidth, EditorGUIUtility.singleLineHeight);
            var col = EditorGUI.ColorField(rectAfterLabel, GUIContent.none, colorProp.colorValue, true,
                false, hdr);
            EditorGUI.indentLevel = indentLevel;
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo(colorProp.displayName);
                colorProp.colorValue = col;
            }
            EditorGUI.showMixedValue = false;
        }

        return rect;
    }
    #endregion
}
