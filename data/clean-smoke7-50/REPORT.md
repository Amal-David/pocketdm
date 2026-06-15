# WP-3 Filter Report

- Total adventures: 50
- Clean adventures: 38
- Raw turns: 669
- Clean turns: 622
- Dropped turns: 47
- Bridge fallback turns: 41

## Drop Reasons

| Reason | Count |
|---|---:|
| bridge | 41 |
| choices_embedding_distinct | 1 |
| profanity_clean | 5 |

## Turn Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| schema_valid | 628 | 628 | 100.0% |
| narration_2_4_sentences | 628 | 628 | 100.0% |
| choices_embedding_distinct | 627 | 628 | 99.8% |
| no_choice_repeated_from_previous_turn | 628 | 628 | 100.0% |
| delta_legal | 628 | 628 | 100.0% |
| profanity_clean | 623 | 628 | 99.2% |
| narration_length_le_600 | 628 | 628 | 100.0% |

## Adventure Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| reached_real_ending | 46 | 50 | 92.0% |
| min_6_turns | 49 | 50 | 98.0% |
| max_1_dropped_turn | 39 | 50 | 78.0% |
