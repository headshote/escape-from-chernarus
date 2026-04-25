// fn_factionRelations.sqf — now much simpler
// Engine handles BLUFOR vs OPFOR natively.
// We only need custom rules for:
//   - Enforcers vs Resistance (both non-OPFOR but enemies)
//   - Enforcers NOT attacking Chernarus Front (both BLUFOR)
//   - Russians ignoring civilians

// Resistance (GUER/Independent) hostile to Enforcers
setFriend [west, resistance, 0];    // BLUFOR hates GUER
setFriend [resistance, west, 0];    // GUER hates BLUFOR
setFriend [resistance, east, 0];    // GUER also fights Russians if chosen

// Russians ignore civilians
setFriend [east, civilian, 1];
setFriend [civilian, east, 1];

// CRN_FRONT and Enforcers are both BLUFOR — engine treats as allies, correct.
// We use CO_faction group variable only to distinguish ENF from FRONT in scripts
// (e.g. desertion detection, conscription pipeline).