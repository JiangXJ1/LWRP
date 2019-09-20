using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEditor.Rendering.PostProcessing;
using UnityEditor;

namespace UnityEditor.Rendering.PostProcessing
{
    [PostProcessEditor(typeof(ToneMapping))]
    internal sealed class ToneMappingEditor : PostProcessEffectEditor<ToneMapping>
    {
        SerializedParameterOverride openToneMapping;
        SerializedParameterOverride openColorGrading;
        SerializedParameterOverride writePoint;
        SerializedParameterOverride blackPoint;

        public override void OnEnable()
        {
            openToneMapping = FindParameterOverride(x => x.toneMapping);
            openColorGrading = FindParameterOverride(x => x.colorGrading);
            writePoint = FindParameterOverride(x => x.writePoint);
            blackPoint = FindParameterOverride(x => x.blackPoint);
        }

        float GetFloatValue(SerializedParameterOverride val, float defaultValue)
        {
            if (val.overrideState.boolValue)
                return val.value.floatValue;
            return defaultValue;
        }

        float SliderValue(float value, float minValue, float maxValue, string name)
        {
            var rect = GUILayoutUtility.GetRect(128, 20);
            EditorGUI.LabelField(new Rect(rect.x, rect.y, 70, 20), new GUIContent(name));
            return EditorGUI.Slider(new Rect(rect.x + 60 + EditorGUI.indentLevel * 15, rect.y, rect.width - 60 - EditorGUI.indentLevel * 15, 20), value, minValue, maxValue);
        }
        
        public override void OnInspectorGUI()
        {
            EditorGUILayout.Space();
            openToneMapping.overrideState.boolValue = true;
            openColorGrading.overrideState.boolValue = true;

            writePoint.overrideState.boolValue = true;
            blackPoint.overrideState.boolValue = true;

            openToneMapping.value.boolValue = EditorGUILayout.Toggle(new GUIContent("Tone Mapping"), openToneMapping.value.boolValue);
            openColorGrading.value.boolValue = EditorGUILayout.Toggle(new GUIContent("Color Grading"), openColorGrading.value.boolValue);
            if (openColorGrading.value.boolValue)
            {
                EditorGUI.indentLevel++;
                EditorGUILayout.LabelField(new GUIContent("white point:"));
                EditorGUI.indentLevel++;
                Vector4 write = writePoint.value.vector4Value;
                write.x = SliderValue(write.x, 0.01f, 5f, "red");
                write.y = SliderValue(write.y, 0.01f, 5f, "green");
                write.z = SliderValue(write.z, 0.01f, 5f, "blue");
                writePoint.value.vector4Value = write;
                EditorGUI.indentLevel--;
                EditorGUILayout.LabelField(new GUIContent("black point:"));
                EditorGUI.indentLevel++;
                Vector4 black = blackPoint.value.vector4Value;
                black.x = SliderValue(Mathf.Min(write.x, black.x), 0.0f, 3f, "red");
                black.y = SliderValue(Mathf.Min(write.y, black.y), 0.0f, 3f, "green");
                black.z = SliderValue(Mathf.Min(write.z, black.z), 0.0f, 3f, "blue");
                blackPoint.value.vector4Value = black;
                EditorGUI.indentLevel--;
                EditorGUI.indentLevel--;
            }

        }


    }
}