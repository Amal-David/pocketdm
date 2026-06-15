# WP-3 Filter Report

- Total adventures: 3
- Clean adventures: 3
- Raw turns: 42
- Clean turns: 41
- Dropped turns: 1
- Bridge fallback turns: 0

## Drop Reasons

| Reason | Count |
|---|---:|
| narration_2_4_sentences | 1 |

## Turn Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| schema_valid | 42 | 42 | 100.0% |
| narration_2_4_sentences | 41 | 42 | 97.6% |
| choices_embedding_distinct | 42 | 42 | 100.0% |
| no_choice_repeated_from_previous_turn | 42 | 42 | 100.0% |
| delta_legal | 42 | 42 | 100.0% |
| profanity_clean | 42 | 42 | 100.0% |
| narration_length_le_600 | 42 | 42 | 100.0% |

## Adventure Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| reached_real_ending | 3 | 3 | 100.0% |
| min_6_turns | 3 | 3 | 100.0% |
| max_1_dropped_turn | 3 | 3 | 100.0% |
