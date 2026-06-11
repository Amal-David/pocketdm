# WP-3 Filter Report

- Total adventures: 6
- Clean adventures: 4
- Raw turns: 76
- Clean turns: 72
- Dropped turns: 4
- Bridge fallback turns: 4

## Drop Reasons

| Reason | Count |
|---|---:|
| bridge | 4 |

## Turn Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| schema_valid | 72 | 72 | 100.0% |
| narration_2_4_sentences | 72 | 72 | 100.0% |
| choices_embedding_distinct | 72 | 72 | 100.0% |
| no_choice_repeated_from_previous_turn | 72 | 72 | 100.0% |
| delta_legal | 72 | 72 | 100.0% |
| profanity_clean | 72 | 72 | 100.0% |
| narration_length_le_600 | 72 | 72 | 100.0% |

## Adventure Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| reached_real_ending | 6 | 6 | 100.0% |
| min_6_turns | 6 | 6 | 100.0% |
| max_1_dropped_turn | 4 | 6 | 66.7% |
