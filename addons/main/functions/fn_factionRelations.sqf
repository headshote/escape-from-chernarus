// fn_factionRelations.sqf
// Engine handles BLUFOR vs OPFOR natively.
// We only need custom rules for:
//   - Enforcers vs Resistance (both non-OPFOR but enemies)
//   - Russians ignore civilians

// Resistance (GUER/Independent) hostile to Enforcers (BLUFOR)
west setFriend [resistance, 0];      // BLUFOR (ENF + FRONT) hates GUER
resistance setFriend [west, 0];      // GUER hates BLUFOR
resistance setFriend [east, 0];      // GUER also fights Russians
east setFriend [resistance, 0];      // Russians fight GUER

// Russians are hostile to Chernarus (BLUFOR)
// This is the default (east vs west) — no override needed.

// Russians ignore civilians (per spec point 18 — RUS_ADV doesn't attack civs).
// This is DELIBERATELY ASYMMETRIC:
//   east -> civilian = 1  : Russians never fire on townsfolk (engine decides
//                           whether east engages a target from east's own
//                           friend rating, so this alone protects civilians).
//   civilian -> east = 0  : civilians are NOT rated friendly toward Russians.
// The second line is the fix for the "destroy a Russian vehicle and the
// Krasnostav conscripts turn on you" bug. A deployed conscript is still
// civilian-SIDE in the engine (a player's slot side can't be changed at
// runtime — see fn_deployToFront). If civilians were friendly to east, then
// killing east crew counted as FRIENDLY FIRE: the player's rating cratered
// past -2000 and the engine flagged them RENEGADE (hostile to everyone,
// including the west CRN_FRONT conscripts). With civilian->east = 0, every
// Russian the deployed conscript kills scores as an enemy kill (positive
// rating), so they can never renegade no matter how many waves they clear.
// Civilians remain unarmed/passive, so this direction never makes townsfolk
// pick fights with Russians.
east setFriend [civilian, 1];
civilian setFriend [east, 0];

// BLUFOR and civilians stay engine-friendly (=1) so police don't blast every
// civilian they roll past and so female civilians aren't autoshot. All TCK
// aggression on civilians is scripted instead, via fn_guardAggroLoop +
// fn_checkpointAlert which use fireAtTarget to bypass relations.
civilian setFriend [west, 1];
west setFriend [civilian, 1];

// NOTE: ENF and CRN_FRONT are BOTH west/BLUFOR.
// We use CO_faction group variable to distinguish them in scripts
// (e.g. desertion detection, conscription pipeline).
// In engine they are allies — ENF will NOT shoot FRONT conscripts..