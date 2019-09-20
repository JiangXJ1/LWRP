using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine.Rendering;

public class TerrainLightingGUI : ShaderGUI
{
    static SavedBoolValue baseDrawInfo;
    static SavedBoolValue[] showLayers4Settings;
    static GUIContent[] layerTitles;
    
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
        if (baseDrawInfo == null)
            baseDrawInfo = new SavedBoolValue("MaterialEditor_TerrainLighting:BaseInfo", true);
        if (layerTitles == null)
        {
            layerTitles = new GUIContent[4];
            showLayers4Settings = new SavedBoolValue[4];
            for(int i = 0; i < 4; ++i)
            {
                layerTitles[i] = new GUIContent("Layer "+(i + 1), "Layer1Settings");
                showLayers4Settings[i] = new SavedBoolValue("MaterialEditor_TerrainLighting:" + i, false);
            }
        }
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

    void DrawBaseInfo()
    {
        baseDrawInfo.value = EditorGUILayout.BeginFoldoutHeaderGroup(baseDrawInfo.value, new GUIContent("Base Info"));
        if (baseDrawInfo.value)
        {
            EditorGUI.BeginChangeCheck();
            bool closeLightGI = material.IsKeywordEnabled("LIGHT_MIX_GI_OFF");
            bool recvFogInfo = material.IsKeywordEnabled("USED_FOG");
            materialEditor.TexturePropertySingleLine(new GUIContent("Control(RGBA)"), FindProperty("_Control"));
            recvFogInfo = EditorGUILayout.Toggle(new GUIContent("Fog"), recvFogInfo);
            if (recvFogInfo)
            {
                EditorGUI.indentLevel++;
                materialEditor.RangeProperty(FindProperty("_FogScale"), "fog scale");
                EditorGUI.indentLevel--;
            }
            closeLightGI = EditorGUILayout.Toggle(new GUIContent("close light gi"), closeLightGI);

            var prop = FindProperty("_SpecType");
            IBaseShaderGUI.DoPopup(new GUIContent("Specular Type"), prop, Enum.GetNames(typeof(IBaseShaderGUI.SpecularType)), materialEditor);
            if (EditorGUI.EndChangeCheck())
            {
                SetKeyWordState("USED_FOG", recvFogInfo);
                SetKeyWordState("LIGHT_MIX_GI_OFF", closeLightGI);
                var specType = (IBaseShaderGUI.SpecularType)(int)prop.floatValue;
                
                SetKeyWordState("SPECULAR_ADD", specType == IBaseShaderGUI.SpecularType.Additional);
                SetKeyWordState("SPECULAR_DEFAULT", specType == IBaseShaderGUI.SpecularType.Default);
                SetKeyWordState("SPECULAR_OFF", specType == IBaseShaderGUI.SpecularType.CloseSpecular);

            }

        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }
    
    void DrawTextureInfo(int index)
    {
        var boolSave = showLayers4Settings[index];
        boolSave.value = EditorGUILayout.BeginFoldoutHeaderGroup(boolSave.value, layerTitles[index]);
        if (boolSave.value)
        {
            EditorGUI.BeginChangeCheck();
            EditorGUI.indentLevel++;
            materialEditor.TextureProperty(FindProperty("_SplatMap" + index), "Layer Map " + (index + 1));
            materialEditor.ColorProperty(FindProperty("_BaseColor" + index), "Base Color" + (index + 1));
            materialEditor.TextureProperty(FindProperty("_BumpMap" + index), "Normal Map " + (index + 1));
            materialEditor.ColorProperty(FindProperty("_SpecColor" + index), "Specular Color " + (index + 1));

            EditorGUI.indentLevel--;
            if (EditorGUI.EndChangeCheck())
            {
                SetKeywordStateWithTextureValue("USED_SPLAT" + index, "_SplatMap" + index);
            }
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    void DrawShaderUI()
    {
        DrawBaseInfo();
        for (int i = 0; i < 4; ++i)
        {
            DrawTextureInfo(i);
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if(isFirstOpen)
            InitProperties(materialEditor, properties);
        DrawShaderUI();
    }
}
