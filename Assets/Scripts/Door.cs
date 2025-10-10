using UnityEngine;

public class Door : MonoBehaviour
{
    public float OpenAngle = 90f;
    public float OpenSpeed = 2f;
    public bool IsOpen = false;

    private Quaternion _closedRotation;
    private Quaternion _openRotation;

    private void Start()
    {
        _closedRotation = transform.localRotation;
        _openRotation = _closedRotation * Quaternion.Euler(0, OpenAngle, 0);
    }

    public void ToggleDoor()
    {
        IsOpen = !IsOpen;
    }

    private void Update()
    {
        if (IsOpen)
        {
            transform.localRotation = Quaternion.Slerp(transform.localRotation, _openRotation, Time.deltaTime * OpenSpeed);
        }
        else
        {
            transform.localRotation = Quaternion.Slerp(transform.localRotation, _closedRotation, Time.deltaTime * OpenSpeed);
        }
    }
}
