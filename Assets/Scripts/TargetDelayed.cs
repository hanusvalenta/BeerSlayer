using UnityEngine;
using System.Collections;

public class TargetDelayed : Target
{
    private bool isBeingFlipped = false;

    public override void ToggleTarget(bool isPlayer)
    {
        if (isPlayer && !isBeingFlipped)
        {
            StartCoroutine(DelayedToggle());
        }
        else if (!isPlayer && !isBeingFlipped)
        {
            IsOpen = !IsOpen;
        }
    }

    private IEnumerator DelayedToggle()
    {
        isBeingFlipped = true;
        yield return new WaitForSeconds(3f);
        IsOpen = !IsOpen;
        isBeingFlipped = false;
    }
}
