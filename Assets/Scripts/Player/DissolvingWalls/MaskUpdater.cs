using UnityEngine;

public class MaskUpdater : MonoBehaviour
{
    public Material wallMaterial;
    public Camera depthCamera; // secondary perspective camera
    public Transform player;

    void Update()
    {
        if (wallMaterial && depthCamera)
        {
            // Feed player position
            wallMaterial.SetVector("_PlayerPos", player.position);

            // Feed depth texture
            wallMaterial.SetTexture("_DepthMap", depthCamera.targetTexture);

            // Feed VP matrix of secondary camera
            Matrix4x4 vp = depthCamera.projectionMatrix * depthCamera.worldToCameraMatrix;
            wallMaterial.SetMatrix("_DepthCam_VP", vp);
        }
    }
}
