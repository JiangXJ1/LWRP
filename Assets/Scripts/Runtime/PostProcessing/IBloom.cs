using System;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.Rendering.PostProcessing;
using Min = UnityEngine.Rendering.PostProcessing.MinAttribute;

/// <summary>
/// This class holds settings for the Bloom effect.
/// </summary>
[Serializable]
[PostProcess(typeof(IBloomRenderer), PostProcessEvent.AfterStack, "PostEffects/Bloom")]
public sealed class IBloom : PostProcessEffectSettings
{
    [Range(0f, 10.0f)]
    public FloatParameter intensity = new FloatParameter { value = 0f };


    [Range(0.0f, 1.0f)]
    public FloatParameter colorFilter = new FloatParameter { value = 0f };

    public ColorParameter addcolor = new ColorParameter { value = Color.white };

    [Range(2, 6)]
    public FloatParameter bloomRnage = new FloatParameter { value = 2f };

    /// <inheritdoc />
    public override bool IsEnabledAndSupported(PostProcessRenderContext context)
    {
        return enabled.value
            && intensity.value > 0f;
    }
}

internal sealed class IBloomRenderer : PostProcessEffectRenderer<IBloom>
{
    static Shader renderShader;
    RenderTexture rt;
    UnityEngine.Rendering.RenderTargetIdentifier rtId;

    Level[] tmplevelIds;
    struct Level
    {
        internal int down;
        internal int up;
    }

    public override void Init()
    {
        if (renderShader == null)
            renderShader = Shader.Find("Hidden/PostProcessing/IBloom");
        tmplevelIds = new Level[10];

        for (int i = 0; i < 10; i++)
        {
            tmplevelIds[i] = new Level
            {
                down = Shader.PropertyToID("_BloomMipDown" + i),
                up = Shader.PropertyToID("_BloomMipUp" + i)
            };
        }
    }

    void UpdateRtSize(int width, int height)
    {
        if (rt == null || rt.width != width || rt.height != height)
        {
            if (rt != null)
                RenderTexture.ReleaseTemporary(rt);
            rt = RenderTexture.GetTemporary(width, height, 0);
            rtId = new UnityEngine.Rendering.RenderTargetIdentifier(rt.colorBuffer);
        }
    }

    public override void Render(PostProcessRenderContext context)
    {
        if (renderShader == null)
            return;
        var cmd = context.command;
        cmd.BeginSample("IBloomRender");
        int width = context.width;
        int height = context.height;
        UpdateRtSize(width, height);
        var sheet = context.propertySheets.Get(renderShader);
        sheet.properties.SetColor(IShaderIds.BloomAddColor, this.settings.addcolor);
        sheet.properties.SetFloat(IShaderIds.BloomMinColor, this.settings.colorFilter);
        sheet.properties.SetFloat(IShaderIds.BloomColorScale, this.settings.intensity);
        

        var lastdown = tmplevelIds[0].down;
        for(int i = 0; i < settings.bloomRnage; ++i)
        {
            var lvl = tmplevelIds[i];
            var downId = lvl.down;
            var upId = lvl.up;

            context.GetScreenSpaceTemporaryRT(cmd, downId, 0, context.sourceFormat, RenderTextureReadWrite.sRGB, FilterMode.Bilinear, width, height);
            context.GetScreenSpaceTemporaryRT(cmd, upId, 0, context.sourceFormat, RenderTextureReadWrite.sRGB, FilterMode.Bilinear, width, height);
            if(i == 0)
            {
                cmd.BlitFullscreenTriangle(context.source, lastdown, sheet, 0);
            }
            else
            {
                cmd.BlitFullscreenTriangle(lastdown, downId, sheet, 1);
            }
            lastdown = downId;
            width = Mathf.Max(width / 2, 1);
            height = Mathf.Max(height / 2, 1);
        }
        int bloomRnage = (int)settings.bloomRnage;
        var lastUp = tmplevelIds[bloomRnage - 1].down;
        for (int i = bloomRnage - 2; i >= 0; --i)
        {
            var lvl = tmplevelIds[i];
            var downId = lvl.down;
            var upId = lvl.up;
            cmd.SetGlobalTexture(IShaderIds.BloomTex, downId);
            cmd.BlitFullscreenTriangle(lastUp, upId, sheet, 2);
            lastUp = upId;
        }
        cmd.SetGlobalTexture(IShaderIds.BloomTex, lastUp);

        cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, 3);

        for (int i = 0; i < bloomRnage; ++i)
        {
            var lvl = tmplevelIds[i];
            var downId = lvl.down;
            var upId = lvl.up;

            cmd.ReleaseTemporaryRT(upId);
            cmd.ReleaseTemporaryRT(downId);
        }
        
        cmd.EndSample("IBloomRender");
    }

    public override void Release()
    {
        base.Release();
    }
}
