# WP-3 Filter Report

- Total adventures: 50
- Clean adventures: 45
- Raw turns: 644
- Clean turns: 632
- Dropped turns: 12
- Bridge fallback turns: 2

## Drop Reasons

| Reason | Count |
|---|---:|
| bridge | 2 |
| choices_embedding_distinct | 6 |
| narration_2_4_sentences | 3 |
| profanity_clean | 1 |

## Turn Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| schema_valid | 642 | 642 | 100.0% |
| narration_2_4_sentences | 639 | 642 | 99.5% |
| choices_embedding_distinct | 636 | 642 | 99.1% |
| no_choice_repeated_from_previous_turn | 642 | 642 | 100.0% |
| delta_legal | 642 | 642 | 100.0% |
| profanity_clean | 641 | 642 | 99.8% |
| narration_length_le_600 | 642 | 642 | 100.0% |

## Adventure Gates

| Gate | Passed | Total | Pass rate |
|---|---:|---:|---:|
| reached_real_ending | 49 | 50 | 98.0% |
| min_6_turns | 48 | 50 | 96.0% |
| max_1_dropped_turn | 47 | 50 | 94.0% |
