# provision.rb — idempotent OpenProject schema for the openproject-intake skill.
# Run: docker compose cp provision.rb web:/tmp/ && \
#      docker compose exec -T web bundle exec rails runner /tmp/provision.rb
# Safe to re-run: every object is found-or-created by name/identifier. Prints SCHEMA_JSON at the end.
require "json"

log = ->(m) { puts "  #{m}" }
schema = { "types" => {}, "fields" => {}, "statuses" => {}, "projects" => {}, "roles" => {} }

# --- 1. Work package types ---------------------------------------------------
def upsert_type(name)
  t = Type.find_by(name: name)
  return [t, false] if t
  t = Type.new(name: name, is_default: false, is_in_roadmap: true, is_milestone: false)
  t.color = Color.first if t.respond_to?(:color=) && Color.any?
  t.position = (Type.maximum(:position) || 0) + 1
  t.save!
  [t, true]
end

%w[Idea].each do |n|
  t, created = upsert_type(n)
  schema["types"][n] = t.id
  log.call "type #{n} ##{t.id} #{created ? '(created)' : '(exists)'}"
end
uc, created = upsert_type("Use case")
schema["types"]["Use case"] = uc.id
log.call "type Use case ##{uc.id} #{created ? '(created)' : '(exists)'}"
epic = Type.find_by(name: "Epic")
schema["types"]["Epic"] = epic&.id
log.call "type Epic ##{epic&.id} (existing)"

idea_type = Type.find_by(name: "Idea")

# --- 2. Custom fields (WorkPackageCustomField) -------------------------------
# fmt: int|float|list ; vals only for list. is_for_all => available in every project.
fields = [
  # name,         format,  seed values,                              multi_value
  ["Reach",      "int",   nil,                                       false],
  ["Impact",     "list",  %w[0.25 0.5 1 2 3],                        false],
  ["Confidence", "list",  %w[50 80 100],                             false],
  ["Effort",     "float", nil,                                       false],
  ["RICE score", "float", nil,                                       false],
  ["Track",      "list",  %w[General],                               false],  # extensible; list needs >=1 seed
  ["Lens",       "list",  %w[Strategic Tactical Philosophical Applied], false],
  ["Horizon",    "list",  %w[Now Next Later],                        false],
  ["Tags",       "list",  %w[security tech-debt quick-win],          true],   # multi-value, cross-cutting, emergent
]

fields.each do |fname, fmt, vals, mv|
  cf = WorkPackageCustomField.find_by(name: fname)
  if cf.nil?
    cf = WorkPackageCustomField.new(name: fname, field_format: fmt, is_required: false, is_for_all: true, is_filter: true)
    cf.multi_value = true if fmt == "list" && mv
    cf.possible_values = vals if fmt == "list"
    cf.save!
    created = true
  else
    # keep list values in sync additively (never remove user-added values)
    if fmt == "list" && vals
      existing = cf.possible_values.map { |v| v.respond_to?(:value) ? v.value : v.to_s }
      merged = (existing + vals).uniq
      if merged.sort != existing.sort
        cf.possible_values = merged; cf.save!
      end
    end
    created = false
  end
  schema["fields"][fname] = cf.id
  # attach to the Idea type so it shows on the form
  unless idea_type.custom_field_ids.include?(cf.id)
    idea_type.custom_field_ids = (idea_type.custom_field_ids + [cf.id]).uniq
    idea_type.save!
  end
  log.call "field #{fname} -> customField#{cf.id} (#{fmt}) #{created ? '(created)' : '(exists)'}"
end

# roadmap Epic also carries Horizon, Track, RICE score (for swimlanes + sorting on the roadmap)
if epic
  roadmap_fids = [schema["fields"]["Horizon"], schema["fields"]["Track"], schema["fields"]["RICE score"], schema["fields"]["Tags"]].compact
  unless (roadmap_fids - epic.custom_field_ids).empty?
    epic.custom_field_ids = (epic.custom_field_ids + roadmap_fids).uniq
    epic.save!
    log.call "synced roadmap fields (Horizon/Track/RICE score/Tags) onto Epic type"
  end
end

# --- 3. Statuses -------------------------------------------------------------
statuses = [
  ["New", false], ["Under review", false], ["In discussion", false],
  ["Approved", false], ["Converted", true], ["Rejected", true], ["Deferred", false],
]
statuses.each do |sname, closed|
  s = Status.find_by(name: sname)
  if s.nil?
    s = Status.create!(name: sname, is_closed: closed, is_default: (sname == "New" && Status.where(is_default: true).none?))
    created = true
  else
    created = false
  end
  schema["statuses"][sname] = s.id
  log.call "status #{sname} ##{s.id} #{created ? '(created)' : '(exists)'}"
end

# --- 4. Workflow: all-pairs transitions for the Idea type, every givable role
idea_status_ids = statuses.map { |sname, _| Status.find_by(name: sname).id }
roles = Role.givable.to_a
roles.each { |r| schema["roles"][r.name] = r.id }
wf_created = 0
roles.each do |role|
  idea_status_ids.each do |from|
    idea_status_ids.each do |to|
      next if from == to
      unless Workflow.exists?(type_id: idea_type.id, old_status_id: from, new_status_id: to, role_id: role.id)
        Workflow.create!(type_id: idea_type.id, old_status_id: from, new_status_id: to, role_id: role.id, author: false, assignee: false)
        wf_created += 1
      end
    end
  end
end
log.call "workflow transitions created this run: #{wf_created} (Idea type, #{roles.size} roles)"

# --- 5. Projects -------------------------------------------------------------
def upsert_project(identifier, name, type_objs)
  p = Project.find_by(identifier: identifier)
  created = p.nil?
  p ||= Project.create!(identifier: identifier, name: name, public: false, workspace_type: "project")
  mods = (p.enabled_module_names + %w[work_package_tracking]).uniq
  p.enabled_module_names = mods
  p.types = (p.types + type_objs).uniq
  p.save!
  [p, created]
end

intake, c1 = upsert_project("intake", "Intake", [idea_type, uc].compact)
schema["projects"]["Intake"] = intake.id
log.call "project Intake ##{intake.id} #{c1 ? '(created)' : '(exists)'}"

roadmap, c2 = upsert_project("roadmap", "Roadmap", [epic].compact)
schema["projects"]["Roadmap"] = roadmap.id
log.call "project Roadmap ##{roadmap.id} #{c2 ? '(created)' : '(exists)'}"

# make admin a member of both with a role that can edit WPs (so API transitions work)
admin = User.find_by(login: "admin")
mgr = Role.givable.detect { |r| r.has_permission?(:edit_work_packages) } || Role.givable.first
[intake, roadmap].each do |proj|
  next unless admin && mgr
  unless Member.exists?(project_id: proj.id, user_id: admin.id)
    m = Member.new(project: proj, principal: admin); m.roles = [mgr]; m.save!
    log.call "added admin to #{proj.identifier} as #{mgr.name}"
  end
end

puts "SCHEMA_JSON=#{schema.to_json}"
