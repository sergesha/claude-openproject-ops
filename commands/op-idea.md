---
description: Register and classify a product idea in the OpenProject intake funnel
argument-hint: "<idea, in your own words>"
---

Capture and triage a new idea using the `openproject-intake` skill.

1. Ensure the intake schema exists (skill's provisioning gate: the scratchpad `## Intake schema`,
   else run `provision.rb`). Search redis-memory for related prior ideas/decisions first.
2. Register `$ARGUMENTS` as a **work package, type Idea, in project Intake**. Title = verb + user
   value; put the raw text + context in the description.
3. **Under review**: screen for duplicates (`search_work_packages`) and link `duplicates` if found;
   set draft **Track** and **Lens**; move status to Under review.
4. If the idea implies concrete scenarios, create/link one or more **Use case** work packages
   (`relates`).
5. Offer to score it (RICE) and take it to In discussion. Report the new `#ID`, Track/Lens, and any
   duplicates found. Do not invent committee/approval steps — the user drives status changes.
