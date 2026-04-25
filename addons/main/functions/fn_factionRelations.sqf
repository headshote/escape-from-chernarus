// fn_factionRelations.sqf
// Engine handles BLUFOR vs OPFOR natively.
// We only need custom rules for:
//   - Enforcers vs Resistance (both non-OPFOR but enemies)
//   - Russians ignore civilians

// Resistance (GUER/Independent) hostile to Enforcers (BLUFOR)
setFriend [west, resistance, 0];    // BLUFOR (ENF + FRONT) hates GUER
setFriend [resistance, west, 0];    // GUER hates BLUFOR
setFriend [resistance, east, 0];    // GUER also fights Russians
setFriend [east, resistance, 0];    // Russians fight GUER

// Russians are hostile to Chernarus (BLUFOR)
// This is the default (east vs west) — no override needed.

// Russians ignore civilians
setFriend [east, civilian, 1];
setFriend [civilian, east, 1];

// Civilians are not hostile to anyone by default
setFriend [civilian, west, 1];
setFriend [west, civilian, 1];

// NOTE: ENF and CRN_FRONT are BOTH west/BLUFOR.
// We use CO_faction group variable to distinguish them in scripts
// (e.g. desertion detection, conscription pipeline).
// In engine they are allies — ENF will NOT shoot FRONT conscripts..