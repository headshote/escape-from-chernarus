// fn_showEscapeUnlockScreen.sqf — client side
// Shows a cinematic title and unlock message

titleText ["YOU ESCAPED\nResistance unlocked on next respawn", "BLACK IN", 0.5];
playSound "CO_unlock_sound";
sleep 5;
titleFadeOut 2;