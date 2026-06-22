# OpenProject instance state — scratchpad (TEMPLATE)

> This is the committed **template** (placeholders only — no host values). The live file is
> `.op-state.local.md`, **gitignored, host-local, NO secrets** (file paths only), at the canonical
> path from `scripts/op-state-path.sh` (`OP_STATE_FILE` if set, else `$HOME/.op-state.local.md`).
> The plugin's SessionStart hook injects it; writers use the same resolver, so reader and writers
> never diverge. Each section is owned and updated by one skill — see `CLAUDE.md` → "Instance
> scratchpad". Scaffolded/populated by `op-setup`. Keep it small (< ~60 lines).

## Instance            <!-- owner: op-setup (openproject-devops) -->
- url:              <https://host>
- version:          <OpenProject x.y.z (tag)>
- deploy_dir:       <path to openproject-docker-compose>
- api_token_file:   <path>   # holds OPENPROJECT_URL + OPENPROJECT_API_KEY (secret stays in the file)
- admin_creds_file: <path>
- write_mcp:        <MCP name + how it is launched>

## Projects            <!-- owner: op-intake (Intake/Roadmap), openproject-pm (delivery projects) -->
- Intake #<id>   → idea + use-case funnel
- Roadmap #<id>  → approved ideas → Now/Next/Later roadmap (Epics)
- <track> #<id>  → delivery project for <track>   (added as delivery projects are created)

## Provisioning IDs    <!-- owner: openproject-pm provisioning -->
- all_projects_admins_group_id: <id>
- project_admin_role_id:        <id>
- group_members:                [<login>, ...]
- type_ids:                     {Task:1, Milestone:2, Summary task:3, Feature:4, Epic:5, User story:6, Bug:7}
- new_projects_seed_types:      [1, 2, 3]
- backlogs_story_types:         [4, 5, 6, 7]
- backlogs_task_type:           1
- backlogs_enabled_on:          [<project #id>, ...]
- backlogs_off_on:              [<project #id>, ...]

## Intake schema       <!-- owner: op-intake / provision.rb -->
- types:    {Idea: <id>, Use case: <id>, Epic: <id>}
- fields:   {Reach: <id>, ...}
- statuses: {New: <id>, ...}
- project:  <intake project #id>
- tags:     {security: <id>, ...}
