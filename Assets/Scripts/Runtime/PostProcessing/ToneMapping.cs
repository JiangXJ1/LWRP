using System;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.Rendering.PostProcessing;
using Min = UnityEngine.Rendering.PostProcessing.MinAttribute;

/// <summary>
/// This class holds settings for the Bloom effect.
/// </summary>
[Serializable]
[PostProcess(typeof(ToneMappingRenderer), PostProcessEvent.BeforeStack, "PostEffects/ToneMapping")]
public sealed class ToneMapping : PostProcessEffectSettings
{
    public BoolParameter toneMapping = new BoolParameter { value = true };
    public BoolParameter colorGrading = new BoolParameter { value = true };
    
    [Range(0.01f, 5)]
    public Vector4Parameter writePoint = new Vector4Parameter { value = Vector4.one };
    [Range(0, 5)]
    public Vector4Parameter blackPoint = new Vector4Parameter { value = Vector4.zero };

    /// <inheritdoc />
    public override bool IsEnabledAndSupported(PostProcessRenderContext context)
    {
        return enabled.value && (colorGrading || toneMapping);
    }
}

internal sealed class ToneMappingRenderer : PostProcessEffectRenderer<ToneMapping>
{
    static Shader renderShader;

    public override void Init()
    {
        if (renderShader == null)
            renderShader = Shader.Find("Hidden/PostProcessing/ToneMapping");
    }
    

    public override void Render(PostProcessRenderContext context)
    {
        if (renderShader == null)
            return;
        var cmd = context.command;
        cmd.BeginSample("IToneMappingRender");

        var sheet = context.propertySheets.Get(renderShader);
        if (settings.colorGrading)
        {
            sheet.EnableKeyword("OPEN_COLORGRADING");
            sheet.properties.SetVector(IShaderIds.ToneMappingWritePoint, settings.writePoint);
            sheet.properties.SetVector(IShaderIds.ToneMappingBlackPoint, settings.blackPoint);
        }
        else
        {
            sheet.DisableKeyword("OPEN_COLORGRADING");
        }
        if (settings.toneMapping)
        {
            sheet.EnableKeyword("OPEN_TONEMAPPING"); 
        }
        else
        {
            sheet.DisableKeyword("OPEN_TONEMAPPING");
        }
        cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        
        cmd.EndSample("IToneMappingRender");
    }

    public override void Release()
    {
        base.Release();
    }
}
