using UnityEngine;

public class Game : MonoBehaviour
{
    // target stuff
    public Target[] targets;
    private float _timeSinceLastFlip = 0f;
    private float _flipInterval = 2f;

    void Awake()
    {
        DontDestroyOnLoad(gameObject);
    }

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }



    // Update is called once per frame
    void Update()
    {
        _timeSinceLastFlip += Time.deltaTime;
        if (_timeSinceLastFlip >= _flipInterval)
        {
            FlipRandomTarget();
            _timeSinceLastFlip = 0f;
            _flipInterval = Random.Range(1f, 3f);
        }
    }

    void FlipRandomTarget()
    {
        int targetIndex = Random.Range(0, targets.Length);

        targets[targetIndex].ToggleTarget(false);
    }
}
