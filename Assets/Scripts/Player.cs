using UnityEngine;
using UnityEngine.SceneManagement;
using TMPro;

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
    private Transform _heldObject = null;
    private Quaternion _heldObjectRotationOffset;

    public TMP_Text ballText;

    public bool[] roomsUnlocked = new bool[3];

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
        HandleHeldObject();
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
        if (Input.GetMouseButtonDown(0) && _heldObject == null)
        {
            Ray ray = playerCamera.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            if (Physics.Raycast(ray, out hit, interactionDistance))
            {
                if (hit.collider.CompareTag("Door"))
                {
                    Door door = hit.collider.GetComponent<Door>();
                    if (door != null && roomsUnlocked[door.DoorID]) door.ToggleDoor();
                }
                else if (hit.collider.CompareTag("Pickable"))
                {
                    _heldObject = hit.transform;
                    _heldObjectRotationOffset = Quaternion.Inverse(transform.rotation) * _heldObject.rotation;
                }
            }
        }
        else if (Input.GetMouseButtonUp(0) && _heldObject != null)
        {
            _heldObject = null;
        }
    }

    private void HandleHeldObject()
    {
        if (_heldObject != null)
        {
            Plane plane = new Plane(Vector3.up, Vector3.up);
            Ray ray = playerCamera.ScreenPointToRay(Input.mousePosition);

            if (plane.Raycast(ray, out float distance))
            {
                Vector3 newPosition = ray.GetPoint(distance);
                _heldObject.position = newPosition;
            }

            _heldObject.rotation = transform.rotation * _heldObjectRotationOffset;
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

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Ball"))
        {
            Destroy(other.gameObject);

            roomsUnlocked[other.GetComponent<Ball>().ballID] = true;
        }
    }
}
