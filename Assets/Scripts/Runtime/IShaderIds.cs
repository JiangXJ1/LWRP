using System;
using UnityEngine;
using System.Collections.Generic;

class IShaderIds
{
    internal static readonly int MainTex = Shader.PropertyToID("_MainTex");

    internal static readonly int BloomTex = Shader.PropertyToID("_BloomTex");

    internal static readonly int PlaneReflectMap = Shader.PropertyToID("_PlaneReflectMap");
    
    internal static readonly int ToneMappingWritePoint = Shader.PropertyToID("whitePoint");
    internal static readonly int ToneMappingBlackPoint = Shader.PropertyToID("blackPoint");


    internal static readonly int BloomAddColor = Shader.PropertyToID("_BloomAddColor");
    internal static readonly int BloomMinColor = Shader.PropertyToID("_BloomMinColor");
    internal static readonly int BloomColorScale = Shader.PropertyToID("_BloomColorScale");
    
    internal static readonly int ReflectFresnel = Shader.PropertyToID("_ReflectFresnel");
    internal static readonly int ReflectThreshold = Shader.PropertyToID("_RefThreshold");
    
}
