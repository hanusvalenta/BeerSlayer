using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class OrtographicDownController : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed = 4f;
    public float sprintSpeed = 7f;
    public float acceleration = 20f;     // how fast we blend to target speed
    public float rotationSpeed = 720f;   // deg/sec to face move direction
    public bool faceMoveDirection = true;

    [Header("Jump & Gravity")]
    public float jumpHeight = 1.2f;
    public float gravity = -20f;
    public Transform groundCheck;
    public float groundCheckRadius = 0.2f;
    public LayerMask groundMask;

    [Header("Camera")]
    public Camera cam; // orthographic camera viewing the scene

    CharacterController controller;
    Vector3 velocity;        // vertical (y) velocity + minor blending help
    Vector3 currentPlanar;   // current horizontal velocity for smoothing

    void Awake()
    {
        controller = GetComponent<CharacterController>();
        if (!cam) cam = Camera.main;
    }

    void Update()
    {
        // --- 1) Input (old Input Manager) ---
        float x = Input.GetAxisRaw("Horizontal");   // A/D or Left/Right
        float z = Input.GetAxisRaw("Vertical");     // W/S or Up/Down
        bool isSprinting = Input.GetKey(KeyCode.LeftShift);
        bool jumpPressed = Input.GetButtonDown("Jump");

        // --- 2) Camera-relative planar direction (flatten camera vectors) ---
        Vector3 camFwd = cam.transform.forward; camFwd.y = 0f; camFwd.Normalize();
        Vector3 camRight = cam.transform.right;   camRight.y = 0f; camRight.Normalize();

        Vector3 inputDir = (camRight * x + camFwd * z);
        inputDir = Vector3.ClampMagnitude(inputDir, 1f);

        float targetSpeed = (isSprinting ? sprintSpeed : walkSpeed) * inputDir.magnitude;
        Vector3 targetPlanar = inputDir * targetSpeed;

        // --- 3) Smooth planar velocity ---
        currentPlanar = Vector3.MoveTowards(currentPlanar, targetPlanar, acceleration * Time.deltaTime);

        // --- 4) Ground check ---
        bool grounded = false;
        if (groundCheck != null)
        {
            grounded = Physics.CheckSphere(groundCheck.position, groundCheckRadius, groundMask, QueryTriggerInteraction.Ignore);
        }
        else
        {
            grounded = controller.isGrounded; // fallback
        }

        if (grounded && velocity.y < 0f)
            velocity.y = -2f; // small stick-to-ground force

        // --- 5) Jump ---
        if (grounded && jumpPressed)
            velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);

        // --- 6) Apply gravity ---
        velocity.y += gravity * Time.deltaTime;

        // --- 7) Move ---
        Vector3 totalMove = currentPlanar + new Vector3(0f, velocity.y, 0f);
        controller.Move(totalMove * Time.deltaTime);

        // --- 8) Face move direction (planar only) ---
        if (faceMoveDirection && inputDir.sqrMagnitude > 0.0001f)
        {
            Quaternion targetRot = Quaternion.LookRotation(inputDir, Vector3.up);
            transform.rotation = Quaternion.RotateTowards(transform.rotation, targetRot, rotationSpeed * Time.deltaTime);
        }
    }

    void OnDrawGizmosSelected()
    {
        if (groundCheck)
        {
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(groundCheck.position, groundCheckRadius);
        }
    }
}
