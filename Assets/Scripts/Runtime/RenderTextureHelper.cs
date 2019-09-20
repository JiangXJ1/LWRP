using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.LWRP;

public static class RenderTextureHelper
{
    static RenderTextureFormat alphaFormat = RenderTextureFormat.Default;
    static RenderTextureFormat RGBFormat = RenderTextureFormat.Default;

    public static RenderTextureFormat GetAlphaTextureFormat()
    {
        if(alphaFormat == RenderTextureFormat.Default)
        {
            if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBFloat))
                alphaFormat = RenderTextureFormat.ARGBFloat;
            else if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf))
                alphaFormat = RenderTextureFormat.ARGBHalf;
            else
                alphaFormat = RenderTextureFormat.ARGB32; 
        }
        return alphaFormat;
    }

    public static RenderTextureFormat GetRGBTextureFormat()
    {
        if (RGBFormat == RenderTextureFormat.Default)
        {
            if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RGB565))
                RGBFormat = RenderTextureFormat.RGB565;
            else
                RGBFormat = RenderTextureFormat.Default;
        }
        return RGBFormat;
    }

    public static void GetRenderTextureMaxSize(ref int width, ref int height)
    {
        var asset = GraphicsSettings.renderPipelineAsset as LightweightRenderPipelineAsset;
        var maxSize = asset.tmpColorBufferMaxSize;
        var size = Mathf.Min(width, height);
        if (size > maxSize)
        {
            float scale = (float)maxSize / size;
            width = (int)(width * scale);
            height = (int)(height * scale);
        }
    }
}