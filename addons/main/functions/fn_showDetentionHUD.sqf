// fn_showDetentionHUD.sqf — client side
// Shows a persistent HUD label during detention phase.
params ["_player"];
titleText ["YOU HAVE BEEN DETAINED\nEscape within 5 minutes or you will be transferred to training.", "BLACK IN", 0.5];
sleep 5;
titleFadeOut 2;
