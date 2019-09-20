using UnityEngine;
using UnityEditor;

public static class Tools
{
    [MenuItem("Tools/Tools/LogInfo")]
    static void DoIt()
    {
        var material = Selection.GetFiltered<Material>(SelectionMode.Assets);
        foreach(var mat in material)
        {
            foreach (var key in mat.shaderKeywords){
                Debug.Log(key);
            }
        }
    }
}