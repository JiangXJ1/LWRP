using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine.Rendering;

public class SSSSLightingGUI : ShaderGUI
{
    public MaterialEditor materialEditor;
    public Material material;
    public Dictionary<string, MaterialProperty> dicAllProperties;
    bool isFirstOpen = true;

    private void InitProperties(MaterialEditor editor, MaterialProperty[] properties)
    {
        materialEditor = editor;
        material = editor.target as Material;
        if (material == null)
            return;
        isFirstOpen = false;
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
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if(isFirstOpen)
            InitProperties(materialEditor, properties);
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(new GUIContent("基础贴图"), FindProperty("_BaseMap"), FindProperty("_BaseColor"));
        materialEditor.TexturePropertySingleLine(new GUIContent("法线贴图"), FindProperty("_BumpMap"), FindProperty("_BumpScale"));
        materialEditor.TexturePropertySingleLine(new GUIContent("控制图", "(r 曲率 g 高光图)"), FindProperty("_FinalMap"));

        materialEditor.TexturePropertySingleLine(new GUIContent("SSSLUT", "控制Diffuse颜色"), FindProperty("_SSSLUTMap"));
        var specTypeProp = FindProperty("_SpecularType");
        IBaseShaderGUI.DoPopup(new GUIContent("SpecularType"), specTypeProp, Enum.GetNames(typeof(IBaseShaderGUI.SpecularType)), materialEditor);
        var specType = (IBaseShaderGUI.SpecularType)(int)specTypeProp.floatValue;
        if(specType != IBaseShaderGUI.SpecularType.CloseSpecular)
        {
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(new GUIContent("KelementLUT", "控制Specular颜色"), FindProperty("_KelementLUTMap"), FindProperty("_SpecularColor"));
            materialEditor.RangeProperty(FindProperty("_SpecularScale"), "高光缩放");
            EditorGUI.indentLevel--;
        }

        bool recvShadow = material.IsKeywordEnabled("RECEIVE_SHADOWS");
        recvShadow = EditorGUILayout.Toggle(new GUIContent("接收阴影"), recvShadow);

        bool closeMixGI = material.IsKeywordEnabled("LIGHT_MIX_GI_OFF");
        closeMixGI = EditorGUILayout.Toggle(new GUIContent("close light gi"), closeMixGI);

        bool hasFog = material.IsKeywordEnabled("USED_FOG");
        hasFog = EditorGUILayout.Toggle(new GUIContent("开启雾效"), hasFog);
        if (hasFog)
        {
            EditorGUI.indentLevel++;
            materialEditor.RangeProperty(FindProperty("_FogScale"), "雾效缩放");
            EditorGUI.indentLevel--;
        }
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyWordState("USED_FOG", hasFog);
            SetKeyWordState("RECEIVE_SHADOWS", recvShadow);
            SetKeyWordState("LIGHT_MIX_GI_OFF", closeMixGI);
            SetKeyWordState("SPECULAR_ADD", specType == IBaseShaderGUI.SpecularType.Additional);
            SetKeyWordState("SPECULAR_DEFAULT", specType == IBaseShaderGUI.SpecularType.Default);
            SetKeyWordState("SPECULAR_OFF", specType == IBaseShaderGUI.SpecularType.CloseSpecular);
        }
        
    }
}
