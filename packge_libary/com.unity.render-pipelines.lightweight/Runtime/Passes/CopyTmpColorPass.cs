using System;

namespace UnityEngine.Rendering.LWRP
{
    /// <summary>
    /// Copy the given color buffer to the given destination color buffer.
    ///
    /// You can use this pass to copy a color buffer to the destination,
    /// so you can use it later in rendering. For example, you can copy
    /// the opaque texture to use it for distortion effects.
    /// </summary>
    internal class CopyTmpColorPass : ScriptableRenderPass
    {
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier destination { get; set; }
        const string m_ProfilerTag = "Copy Tmp Color";

        /// <summary>
        /// Create the CopyColorPass
        /// </summary>
        public CopyTmpColorPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
        }

        /// <summary>
        /// Configure the pass with the source and destination to execute on.
        /// </summary>
        /// <param name="source">Source Render Target</param>
        /// <param name="destination">Destination Render Target</param>
        public void Setup(RenderTargetIdentifier source, RenderTargetIdentifier destination)
        {
            this.source = source;
            this.destination = destination;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescripor)
        {

        }

        /// <inheritdoc/>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            cmd.Blit(source, destination);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// <inheritdoc/>
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
                throw new ArgumentNullException("cmd");
        }
    }
}
