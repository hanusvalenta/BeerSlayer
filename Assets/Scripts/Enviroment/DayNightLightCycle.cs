using UnityEngine;

public class DayNightLightCycle : MonoBehaviour
{
    [Header("References")]
    public Light sun; // Assign your directional light (sun)

    [Header("Cycle Settings")]
    [Tooltip("Length of a full day in real-time seconds")]
    public float dayLength = 60f; // e.g. 60 seconds = full cycle

    [Tooltip("Number of frames (steps) in the cycle, like pixel-art animation frames")]
    public int frameSteps = 30; // quantized frames

    [Tooltip("Start time of day (0 = midnight, 0.25 = 6AM, 0.5 = noon, 0.75 = 6PM)")]
    [Range(0f, 1f)]
    public float currentTimeOfDay = 0f;

    private float sunInitialIntensity;

    void Start()
    {
        if (sun != null)
            sunInitialIntensity = sun.intensity;
    }

    void Update()
    {
        UpdateTimeOfDay();
        RotateSunStepped();
        UpdateLighting();
    }

    void UpdateTimeOfDay()
    {
        currentTimeOfDay += Time.deltaTime / dayLength;

        if (currentTimeOfDay >= 1f)
            currentTimeOfDay = 0f;
    }

    void RotateSunStepped()
    {
        if (sun == null) return;

        // Quantize into discrete frames
        float steppedTime = Mathf.Floor(currentTimeOfDay * frameSteps) / frameSteps;

        float sunAngle = steppedTime * 360f - 90f;
        sun.transform.rotation = Quaternion.Euler(sunAngle, 170f, 0);
    }

    void UpdateLighting()
    {
        if (sun == null) return;

        // Rough stepped lighting for pixel-art vibe
        float steppedTime = Mathf.Floor(currentTimeOfDay * frameSteps) / frameSteps;

        float intensityMultiplier = 1f;
        if (steppedTime <= 0.23f || steppedTime >= 0.75f)
        {
            intensityMultiplier = 0f; // night
        }
        else if (steppedTime <= 0.25f)
        {
            intensityMultiplier = Mathf.Clamp01((steppedTime - 0.23f) / 0.02f);
        }
        else if (steppedTime >= 0.73f)
        {
            intensityMultiplier = Mathf.Clamp01(1 - ((steppedTime - 0.73f) / 0.02f));
        }

        sun.intensity = sunInitialIntensity * intensityMultiplier;

        // Ambient light also stepped
        RenderSettings.ambientLight = Color.Lerp(Color.black, Color.gray, intensityMultiplier);
    }
}
