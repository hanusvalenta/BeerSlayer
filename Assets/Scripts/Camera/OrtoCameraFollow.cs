using UnityEngine;

public class OrtoCameraFollow : MonoBehaviour
{
    public Transform target;
    public Vector3 offset = new Vector3(0f, 20f, 0f); // for top-down; for isometric, use a tilted offset
    public float followSmooth = 10f;

    void LateUpdate()
    {
        if (!target) return;
        Vector3 desired = target.position + offset;
        transform.position = Vector3.Lerp(transform.position, desired, 1f - Mathf.Exp(-followSmooth * Time.deltaTime));
        // Keep whatever rotation you’ve set in the editor for the look angle.
    }
}
