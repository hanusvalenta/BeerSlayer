using UnityEngine;

public class Player : MonoBehaviour
{
    public float moveSpeed = 8f;
    
    public Camera playerCamera;
    [Range(0.01f, 1f)]
    public float cameraPositionSmoothTime = 0.1f;
    public float cameraRotationSmoothTime = 0.5f;
    public Vector3 cameraOffset = new Vector3(0, 5, -10);

    public float interactionDistance = 3f;

    private CharacterController _characterController;
    private Vector3 _cameraVelocity = Vector3.zero;

    void Start()
    {
        _characterController = GetComponent<CharacterController>();
        if (_characterController == null)
        {
            _characterController = gameObject.AddComponent<CharacterController>();
        }
    }

    void Update()
    {
        HandleMovement();
        HandleInteraction();
    }

    void LateUpdate()
    {
        HandleCamera();
    }

    private void HandleMovement()
    {
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        Vector3 moveDirection = new Vector3(horizontal, 0, vertical);
        _characterController.SimpleMove(moveDirection * moveSpeed);
    }

    private void HandleInteraction()
    {
        if (!Input.GetMouseButtonDown(0)) return;

        Ray ray = playerCamera.ScreenPointToRay(Input.mousePosition);
        RaycastHit hit;

        if (Physics.Raycast(ray, out hit))
        {
            if (hit.collider.CompareTag("Door") && Vector3.Distance(transform.position, hit.transform.position) <= interactionDistance)
            {
                Door door = hit.collider.GetComponent<Door>();
                if (door != null) door.ToggleDoor();
            }
        }
    }

    private void HandleCamera()
    {
        if (playerCamera == null) return;

        Vector3 desiredPosition = transform.position + cameraOffset; 
        Vector3 smoothedPosition = Vector3.SmoothDamp(playerCamera.transform.position, desiredPosition, ref _cameraVelocity, cameraPositionSmoothTime);
        playerCamera.transform.position = smoothedPosition;

        Quaternion targetRotation = Quaternion.LookRotation(transform.position - playerCamera.transform.position);
        playerCamera.transform.rotation = Quaternion.Slerp(playerCamera.transform.rotation, targetRotation, cameraRotationSmoothTime * Time.deltaTime);
    }
}
