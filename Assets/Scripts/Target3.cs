using UnityEngine;

public class Target3 : Target
{
    public int clicked = 0;

    public override void ToggleTarget(bool isPlayer)
    {
        if (isPlayer){
                clicked++;
            if (clicked >= 3)
            {
                IsOpen = !IsOpen;
                clicked = 0;
            }
        }
        if (!isPlayer){
            IsOpen = !IsOpen;
        }
    }
}

