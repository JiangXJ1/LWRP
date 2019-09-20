
using UnityEngine.Rendering;

namespace UnityEngine.Rendering.LWRP
{
    public struct RenderTargetHandle
    {
        public int id { set; get; }
        public RenderTargetIdentifier identify { set; get; }

        public static readonly RenderTargetHandle CameraTarget = new RenderTargetHandle {id = -1};

        public void Init(string shaderProperty)
        {
            id = Shader.PropertyToID(shaderProperty);
            identify = new RenderTargetIdentifier(id);
        }

        public RenderTargetIdentifier Identifier()
        {
            if (id == -1)
            {
                return BuiltinRenderTextureType.CameraTarget;
            }
            return identify;
        }

        public bool Equals(RenderTargetHandle other)
        {
            return id == other.id;
        }

        public override bool Equals(object obj)
        {
            if (ReferenceEquals(null, obj)) return false;
            return obj is RenderTargetHandle && Equals((RenderTargetHandle)obj);
        }

        public override int GetHashCode()
        {
            return id;
        }

        public static bool operator==(RenderTargetHandle c1, RenderTargetHandle c2)
        {
            return c1.Equals(c2);
        }

        public static bool operator!=(RenderTargetHandle c1, RenderTargetHandle c2)
        {
            return !c1.Equals(c2);
        }
    }
}
