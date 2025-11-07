using UnityEngine;

public class Drawer : MonoBehaviour
{
    public float openDistance = 0.5f;
    public float OpenSpeed = 2f;
    public bool IsOpen = false;

    public int DoorID;

    private Vector3 _closedPosition;
    private Vector3 _openPosition;

    private void Start()
    {
        _closedPosition = transform.localPosition;
        _openPosition = _closedPosition + Vector3.forward * openDistance;
    }

    public void ToggleDoor()
    {
        IsOpen = !IsOpen;
    }

    private void Update()
    {
        if (IsOpen)
        {
            transform.localPosition = Vector3.Lerp(transform.localPosition, _openPosition, Time.deltaTime * OpenSpeed);
        }
        else
        {
            transform.localPosition = Vector3.Lerp(transform.localPosition, _closedPosition, Time.deltaTime * OpenSpeed);
        }
    }
}
