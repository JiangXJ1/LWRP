
/********************************************************************
 FileName: PlanarReflection.cs
 Description: 平面反射效果
*********************************************************************/
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using UnityEngine.Rendering.LWRP;

public class PlanarReflection : MonoBehaviour
{
    int frameCount = 0;
    int curFrameCount = 0;
    float timeLength = 0;
    
    private static List<PlanarReflection> listAllReflection = new List<PlanarReflection>();

    bool cameraRendering = false;
    bool currentCameraEnable = true;

    private static bool globalEnable = true;
    public static bool globalReflectEnable
    {
        get
        {
            return globalEnable;
        }
        set
        {
            if(globalEnable != value)
            {
                globalEnable = value;
                for(int i = 0; i < listAllReflection.Count; ++i)
                {
                    listAllReflection[i].UpdateReflection();
                }
            }
        }
    }
    public static int reflectionLayerMask = 0;

    [SerializeField, Range(2, 6)]
    private int TextureDownSample = 6   ;
    [SerializeField]
    private CameraClearFlags cameraClearFlags = CameraClearFlags.Color;
    [SerializeField]
    private Color backGroundColor = Color.black;
    [SerializeField]
    private float farClipPanel = 10f;
    [SerializeField]
    private float nearClipPanel = 0.1f;
    [SerializeField, Range(0, 1)]
    private float ReflectFresnel = 0.1f;
    [SerializeField, Range(0, 1)]
    private float RefThreshold = 0.1f;
    
    private Camera currentCamera = null;
    private Camera reflectionCamera = null;
    private RenderTexture reflectionRT = null;
    private RenderTexture reflectionBlurRT = null;
    private Material cache_mat = null;
    private Material material
    {
        get
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
                return null;
#endif
            if(cache_mat == null)
            {
                var render = GetComponent<Renderer>();
                cache_mat = render.sharedMaterial;
            }
            return cache_mat;
        }
    }
    private bool selfReflectEnable = false;
    private bool reflectEnable
    {
        get
        {
            return material != null && selfReflectEnable && globalReflectEnable && isActiveAndEnabled;
        }
    }


    private void UpdateRenderTexture(int width, int height)
    {
        if (reflectionCamera == null)
            return;
        if(reflectionRT == null || width != reflectionRT.width || height != reflectionRT.height)
        {
            if(reflectionRT != null)
            { 
                reflectionCamera.targetTexture = null;
                DestroyImmediate(reflectionRT);
                reflectionRT = null;
            }
            reflectionRT = new RenderTexture(width, height, 16, RenderTextureHelper.GetRGBTextureFormat(), RenderTextureReadWrite.sRGB);
            reflectionRT.filterMode = FilterMode.Bilinear;
            if (TextureDownSample >= 4)
                reflectionRT.antiAliasing = 2;
            reflectionCamera.targetTexture = reflectionRT;
            material.SetTexture(IShaderIds.PlaneReflectMap, reflectionRT);
            material.EnableKeyword("USING_REFLECTION");
            material.SetFloat(IShaderIds.ReflectFresnel, ReflectFresnel);
            material.SetFloat(IShaderIds.ReflectThreshold, RefThreshold);
        }
#if UNITY_EDITOR
        if(material != null)
        {
            material.SetFloat(IShaderIds.ReflectFresnel, ReflectFresnel);
            material.SetFloat(IShaderIds.ReflectThreshold, RefThreshold);
        }
#endif
    }

    private void OnWillRenderObject()
    {
        currentCamera = Camera.current;
    }

    private void UpdateCameraEnable()
    {
        if(reflectionCamera != null)
        {
            reflectionCamera.enabled = reflectEnable && cameraRendering && currentCameraEnable;
        }
    }

    private void OnBecameInvisible()
    {
        cameraRendering = false;
        UpdateCameraEnable();
    }

    private void OnBecameVisible()
    {
        cameraRendering = true;
        UpdateCameraEnable();
    }

    private void LateUpdate()
    {
        curFrameCount++;
        timeLength += Time.unscaledDeltaTime;
        if (timeLength > 1)
        {
            frameCount = curFrameCount;
            timeLength = 0;
            curFrameCount = 0;
        }

        UpdateCameraInfo();
#if UNITY_EDITOR
        if(this.reflectionCamera != null && this.currentCamera != null)
        {
            if(UnityEditor.SceneView.currentDrawingSceneView != null && this.currentCamera == UnityEditor.SceneView.currentDrawingSceneView.camera)
            {
                currentCameraEnable = false;
            }
            else
            {
                currentCameraEnable = true;
            }
        }
        UpdateCameraEnable();
        this.currentCamera = null;
#endif
    }

    private void UpdateReflection()
    {
        if (reflectEnable)
        {
            if (reflectionCamera == null)
            {
                var go = new GameObject("Reflection Camera");
                go.transform.parent = this.transform;

                reflectionCamera = go.AddComponent<Camera>();
                LWRPAdditionalCameraData data = go.GetComponent<LWRPAdditionalCameraData>();
                if(data == null)
                    data = go.AddComponent<LWRPAdditionalCameraData>();
                data.invertCulling = true;
                data.requiresColorTexture = false;
                data.requiresDepthTexture = false;
                data.renderShadows = false;
                UpdateCameraInfo();
            }
        }
        else
        {
            if (reflectionCamera != null)
            {
                reflectionCamera.targetTexture = null;
                DestroyImmediate(reflectionRT);
                reflectionRT = null;
                Destroy(reflectionCamera.gameObject);
                reflectionCamera = null;
            }
            if(material != null)
            {
                material.DisableKeyword("USING_REFLECTION");
            }
        }
    }

    private void SetReflectEnable(bool enable)
    {
        if (selfReflectEnable == enable)
            return;
        selfReflectEnable = enable;
        UpdateReflection();
    }

    private void OnEnable()
    {
        listAllReflection.Add(this);
#if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            SetReflectEnable(false);
            return;
        }
#endif
        SetReflectEnable(true);
    }

    private void OnDisable()
    {
        listAllReflection.Remove(this);
        SetReflectEnable(false);
    }

    private void UpdateCameraInfo()
    {
        var currentCamera = this.currentCamera == null ? Camera.main : this.currentCamera;
        if (currentCamera == null)
        {
            SetReflectEnable(false);
        }
        if (reflectEnable)
        {
            reflectionCamera.enabled = true;
            int width = Screen.width;
            int height = Screen.height;
            RenderTextureHelper.GetRenderTextureMaxSize(ref width, ref height);
            UpdateRenderTexture(width / TextureDownSample, height / TextureDownSample);
            //需要实时同步相机的参数，比如编辑器下滚动滚轮，Editor相机的远近裁剪面就会变化
            UpdateCamearaParams(currentCamera, reflectionCamera);

            var reflectM = CaculateReflectMatrix();
            reflectionCamera.worldToCameraMatrix = currentCamera.worldToCameraMatrix * reflectM;
             
            var normal = transform.up;
            var d = -Vector3.Dot(normal, transform.position);
            var plane = new Vector4(normal.x, normal.y, normal.z, d);
            //用逆转置矩阵将平面从世界空间变换到反射相机空间
            reflectionCamera.projectionMatrix = CaculateObliqueViewFrustumMatrix(plane);
        }
        UpdateCameraEnable();
    }

    Matrix4x4 CaculateReflectMatrix()
    {
        var normal = transform.up;
        var d = -Vector3.Dot(normal, transform.position);
        var reflectM = new Matrix4x4();
        reflectM.m00 = 1 - 2 * normal.x * normal.x;
        reflectM.m01 = -2 * normal.x * normal.y;
        reflectM.m02 = -2 * normal.x * normal.z;
        reflectM.m03 = -2 * d * normal.x;

        reflectM.m10 = -2 * normal.x * normal.y;
        reflectM.m11 = 1 - 2 * normal.y * normal.y;
        reflectM.m12 = -2 * normal.y * normal.z;
        reflectM.m13 = -2 * d * normal.y;

        reflectM.m20 = -2 * normal.x * normal.z;
        reflectM.m21 = -2 * normal.y * normal.z;
        reflectM.m22 = 1 - 2 * normal.z * normal.z;
        reflectM.m23 = -2 * d * normal.z;

        reflectM.m30 = 0;
        reflectM.m31 = 0;
        reflectM.m32 = 0;
        reflectM.m33 = 1;
        return reflectM;
    }

    private void UpdateCamearaParams(Camera srcCamera, Camera destCamera)
    {
        if (destCamera == null || srcCamera == null)
            return;

        destCamera.clearFlags = cameraClearFlags;
        destCamera.backgroundColor = backGroundColor;
        destCamera.farClipPlane = farClipPanel;
        destCamera.nearClipPlane = nearClipPanel;
        destCamera.orthographic = srcCamera.orthographic;
        destCamera.fieldOfView = srcCamera.fieldOfView;
        destCamera.aspect = srcCamera.aspect;
        destCamera.orthographicSize = srcCamera.orthographicSize;
        if(reflectionLayerMask == 0)
        {
            destCamera.cullingMask = LayerMask.GetMask("Default");
        }
        else
        {
            destCamera.cullingMask = reflectionLayerMask;
        }
    }

    private Matrix4x4 CaculateObliqueViewFrustumMatrix(Vector4 plane)
    {
        //世界空间的平面先变换到相机空间
        plane = (reflectionCamera.worldToCameraMatrix.inverse).transpose * plane;


        Matrix4x4 proj = reflectionCamera.projectionMatrix;

        //计算近裁面的最远角点Q
        Vector4 q = default(Vector4);
        q.x = (Mathf.Sign(plane.x) + proj.m02) / proj.m00;
        q.y = (Mathf.Sign(plane.y) + proj.m12) / proj.m11;
        q.z = -1.0f;
        q.w = (1.0f + proj.m22) / proj.m23;
        Vector4 c = plane * (2.0f / Vector4.Dot(plane, q));

        //计算M3'
        proj.m20 = c.x;
        proj.m21 = c.y;
        proj.m22 = c.z + 1.0f;
        proj.m23 = c.w;

        return proj;
    }


    private void OnGUI()
    {
        QualitySettings.vSyncCount = 0;
        GUIStyle style = new GUIStyle();
        style.normal.background = null;
        style.normal.textColor = new Color(1, 1, 1, 1);
        style.fontSize = 50;
        GUI.Label(new Rect(10, 10, Screen.width, 100), string.Format("FPS:{0}, Camera:{1}, Texture:{2}, MaterialKey:{3}", frameCount, reflectionCamera == null ? "null":reflectionCamera.enabled.ToString(), reflectionRT == null ? "null" : reflectionRT.width.ToString(), material == null ? "null":material.IsKeywordEnabled("OPEN_REFLECTION").ToString()), style);
    }
}