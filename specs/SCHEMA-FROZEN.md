# PocketDM Turn Schema Is Frozen

WP-1 freezes the JSON contract shared by prompts, data generation, grammar-constrained decoding, engine validation, evaluation, and training.

## Canonical JSON

```json
{
  "narration": "You lift the lantern and the stairwell exhales cold dust.",
  "choices": [
    "Raise the shield",
    "Search the alcove",
    "Call into the dark"
  ],
  "state_delta": {
    "hp": 0,
    "add_items": [
      "lantern"
    ],
    "remove_items": [],
    "location": "Sunken Stair",
    "add_flags": [
      "heard_whispers"
    ]
  },
  "is_ending": false,
  "ending_type": null
}
```

## Key Order

Top-level keys are always:

1. `narration`
2. `choices`
3. `state_delta`
4. `is_ending`
5. `ending_type`

`state_delta` keys are always:

1. `hp`
2. `add_items`
3. `remove_items`
4. `location`
5. `add_flags`

## Change Rule

Any change to this schema, key order, enum set, or grammar shape requires regenerating synthetic data, regenerating `engine/grammar.gbnf`, rerunning schema and grammar tests, and retraining the student model. Do not make casual schema edits.
