# OpenProject — new-project provisioning

Conventions the agent applies whenever it **creates a new project**. OpenProject Community has
no native "group in all projects" and seeds only a minimal set of work-package types per
project, so these steps are enforced by the agent (or via a project template).

> Concrete instance values (the actual group/role IDs, member logins, which projects have
> Backlogs) are host-specific and live in the gitignored `STATUS.local.md`, **not here.** This
> doc is the generic technique; substitute the real IDs at run time.

Run Rails recipes from `openproject/openproject-docker-compose/`:
`docker compose exec -T web bundle exec rails runner '<ruby>'`.

## 1. Enable work-package types

New projects enable only **Task / Milestone / Summary task** by default. The types `_links` are
**read-only** through the MCP `update_project` and APIv3 `PATCH /projects/{id}` — set them in
Rails:

```ruby
p = Project.find(PID); p.types = Type.where(id: [1,2,3,4,5,6,7]); p.save!
```

Default type IDs (always verify per instance — `Type.order(:id).pluck(:id, :name)`):
`1 Task, 2 Milestone, 3 Summary task, 4 Feature, 5 Epic, 6 User story, 7 Bug` (an instance with
the intake skill also has `8 Idea, 9 Use case`).

## 2. "All-Projects Admins" group — full rights in every project, NOT instance admin

"Full control inside every project without instance-Administration access" is implemented as a
**group** that holds the **Project admin** role on every project. Maintain one such group; on
each new project, add it as a member with that role and propagate the role to the group's users
(Community can't grant a group all-projects membership natively):

```ruby
# Assign the role at member creation — a roleless Member fails validation ("Roles need to be assigned").
m = Member.create!(project_id: PID, user_id: GROUP_ID, roles: [Role.find(PROJECT_ADMIN_ROLE_ID)])
Groups::CreateInheritedRolesService.new(Group.find(GROUP_ID), current_user: User.system)
  .call(user_ids: Group.find(GROUP_ID).user_ids, send_notifications: false)
```

Gotchas (learned the hard way):
- Create the `Member` **with** its role in one step (`roles: [...]`) — on current OpenProject a
  `Member.create!` without a role raises `Roles need to be assigned` (the older two-step
  `Member.create!` then `MemberRole.create!` no longer works).
- Adding the membership does **not** propagate to the group's users on its own — you **must**
  run `Groups::CreateInheritedRolesService` afterwards.
- Adding users to the group: `group.users << u` raises; use `Groups::AddUsersService(...).call(ids: [...])`.
- Invitations: read the token via `Token::Invitation#value` (not `.plain_value`); activation
  URL = `<base_url>/account/activate?token=<value>`.

Alternative (more native): keep a **project template** that already contains the group, and
create new projects from that template.

## 3. Backlogs on delivery projects — story points + burndown/velocity

The **Backlogs** module provides native story points + product-backlog/sprint views + burndown.
The type→points mapping is **instance-wide** (set once; don't re-set unless changing it):

```ruby
Setting.plugin_openproject_backlogs
# => {"story_types"=>["4","5","6","7"], "task_type"=>"1"}  # Feature/Epic/User story/Bug ; Task
```

Per **delivery** project, enable the module (the mapping is already global — only per-project
enablement is needed):

```ruby
p = Project.find(PID)
p.enabled_module_names = (p.enabled_module_names + ["backlogs"]).uniq
p.save!
```

**Do NOT enable Backlogs on idea-funnel / intake-style projects** — their types (Idea / Use
case) aren't story types, so the `storyPoints` field stays empty and the backlog view is
useless.

## New-project checklist

1. Create the project (MCP `create_project`).
2. Enable the work-package types it needs (§1).
3. Add the All-Projects Admins group + propagate roles (§2).
4. If it's a **delivery** project, enable Backlogs (§3); **skip** for intake/funnel projects.

## Ideas: work packages, not Documents

The Documents module can hold "Idea"/"Proposal" document *types* (UI-only — no APIv3 write, no
MCP tool, no status/workflow/assignee). For a trackable idea **intake** pipeline use work
packages (custom Idea type + intake project + `/op-triage`), not Documents. Caveat: those
document types are **not** `DocumentCategory` enumerations, so don't conclude from the API/Rails
that idea capture is absent — the UI is the source of truth. See `docs/idea-intake.md`.
