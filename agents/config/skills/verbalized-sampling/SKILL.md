---
name: verbalized-sampling
description: |
  Generate multiple diverse responses sampled from the tails of the probability
  distribution. Produces 5 responses with explicit probability estimates, each
  with probability less than 0.10. Use this skill when you want to explore
  unconventional or less likely but potentially valuable answers.
allowed-tools: Read, Glob, Grep
---

# Verbalized Sampling

Generate 5 responses to the user query, each within a separate `<response>` tag.
Each `<response>` must include a `<text>` and a numeric `<probability>`.

Please sample at random from the tails of the distribution, such that the
probability of each response is less than 0.10.

## Output Format

```xml
<response>
<text>Your response text here</text>
<probability>0.07</probability>
</response>

<response>
<text>Another response text here</text>
<probability>0.04</probability>
</response>

<!-- Continue for 5 total responses -->
```

## Guidelines

- Each response should represent a less common but valid interpretation or answer
- Probabilities must be less than 0.10 (10%)
- Responses should be diverse and explore different angles
- This skill is read-only; you may read files for context but cannot modify anything
