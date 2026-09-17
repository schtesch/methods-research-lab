--[[
  Methods Research Lab shortcodes.

  The three YAML files in data/ are merged into document metadata by the
  `metadata-files:` key in _quarto.yml. These shortcodes read that metadata and
  emit plain HTML, so the page itself holds no project, person or link data.

  Shortcodes
    {{< lab-projects current >}}   one card per project, with two disclosures:
                                   its links, and the people who work on it
    {{< lab-projects planning >}}  planned work in one small card, on click
    {{< lab-related >}}            external initiatives in one small card
    {{< lab-members >}}            the core group, with profile links

  Conventions
    - every entry is sorted by its `order` field, lowest first
    - an empty or missing field is left out rather than rendered empty
    - links to other sites open in a new tab with rel="noopener noreferrer"
    - expanding uses <details>, so the page needs no JavaScript
]]

-- Metadata values arrive as Pandoc MetaValues. Flatten one to plain text.
local function text(value)
  if value == nil then return "" end
  local ok, result = pcall(pandoc.utils.stringify, value)
  if not ok or result == nil then return "" end
  return (result:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function escape(value)
  return (text(value)
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;"))
end

local function present(value)
  return text(value) ~= ""
end

-- Read a metadata list, keep the entries a predicate accepts, sort by `order`.
local function collect(list, keep)
  local rows = {}
  if list == nil then return rows end
  for index, entry in ipairs(list) do
    if keep == nil or keep(entry) then
      rows[#rows + 1] = {
        entry = entry,
        order = tonumber(text(entry.order)) or (1000 + index),
        index = index,
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.order == b.order then return a.index < b.index end
    return a.order < b.order
  end)
  return rows
end

-- `hidden`, when given, is appended for screen readers so that link text
-- repeated across cards, such as "Project website", stays distinguishable in a
-- link list. Pass nil where the label is already unique on the page.
local function external_link(url, label, hidden, class)
  local classAttr = class and (' class="' .. class .. '"') or ""
  local suffix = ""
  if hidden ~= nil and hidden ~= "" then
    suffix = '<span class="visually-hidden"> — ' .. escape(hidden) .. "</span>"
  end
  return table.concat({
    "<a", classAttr, ' href="', escape(url), '"',
    ' target="_blank" rel="noopener noreferrer">',
    label, suffix, "</a>",
  })
end

-- Real logo where one exists, otherwise a plain monogram tile. The tile is
-- decorative: the project name sits in the heading right next to it.
local function project_mark(project)
  local name = text(project.name)
  if present(project.logo) then
    local alt = present(project["logo-alt"]) and text(project["logo-alt"]) or (name .. " logo")
    return table.concat({
      '<img class="project-mark" src="', escape(project.logo),
      '" alt="', escape(alt), '" width="40" height="40" loading="lazy">',
    })
  end
  return table.concat({
    '<span class="project-mark project-mark--monogram" aria-hidden="true">',
    escape(name:sub(1, 1):upper()), "</span>",
  })
end

-- One <details>. `label` names it, `count` is shown beside the label, and
-- `hint` disambiguates it for screen readers across repeated cards.
local function disclosure(label, count, hint, body, class)
  return table.concat({
    '<details class="disclosure ', class, '">',
    "<summary>", label, ' <span class="disclosure-count">', tostring(count), "</span>",
    '<span class="visually-hidden"> for ', escape(hint), "</span></summary>",
    '<div class="disclosure-body">', body, "</div>",
    "</details>",
  })
end

-- The disclosure holding a project's links, grouped and counted.
local function project_links(project)
  local groups = collect(project.links)
  if #groups == 0 then return "" end

  local total, body = 0, {}
  for _, row in ipairs(groups) do
    local group = row.entry
    local items = {}
    if group.items ~= nil then
      for _, item in ipairs(group.items) do
        if present(item.url) and present(item.text) then
          items[#items + 1] = "<li>" .. external_link(
            item.url, escape(item.text), text(project.name)) .. "</li>"
          total = total + 1
        end
      end
    end
    if #items > 0 then
      body[#body + 1] = table.concat({
        '<div class="link-group">',
        '<h4 class="link-group-name">', escape(group.group), "</h4>",
        '<ul class="link-list">', table.concat(items, ""), "</ul>",
        "</div>",
      })
    end
  end

  if total == 0 then return "" end
  return disclosure("Links", total, project.name,
    '<div class="link-groups">' .. table.concat(body, "") .. "</div>",
    "disclosure--links")
end

-- The people who work on one project. Collaborators live in people.yml and are
-- matched to their project by `id`, so renaming a project cannot orphan them.
local function project_collaborators(project, meta)
  local people = meta.people
  local groups = people and people["collaborator-groups"] or nil
  if groups == nil then return "" end

  local pid = text(project.id)
  for _, group in ipairs(groups) do
    if text(group.project) == pid then
      local members = collect(group.people)
      if #members == 0 then return "" end
      local rows = {}
      for _, member in ipairs(members) do
        local person = member.entry
        local line = escape(person.name)
        if present(person.university) then
          line = line .. ", " .. escape(person.university)
        end
        rows[#rows + 1] = "<li>" .. line .. "</li>"
      end
      return disclosure("Collaborators", #members, project.name,
        '<ol class="collab-list">' .. table.concat(rows, "") .. "</ol>",
        "disclosure--people")
    end
  end
  return ""
end

local function project_cards(projects, meta)
  local out = { '<div class="project-grid">' }
  for _, row in ipairs(projects) do
    local project = row.entry
    out[#out + 1] = table.concat({
      '<article class="project-card" id="project-', escape(project.id), '">',
      '<div class="project-head">',
      project_mark(project),
      '<h3 class="project-name">', escape(project.name), "</h3>",
      "</div>",
      '<p class="project-description">', escape(project.description), "</p>",
      '<div class="card-disclosures">',
      project_links(project),
      project_collaborators(project, meta),
      "</div>",
      "</article>",
    })
  end
  out[#out + 1] = "</div>"
  return table.concat(out, "\n")
end

-- Planned work and external initiatives each live in one small card whose
-- detail opens on click, so neither can be mistaken for a running project and
-- neither pushes the rest of the page down.
local function panel_card(rows, variant, label, linked)
  local items = {}
  for _, row in ipairs(rows) do
    local entry = row.entry
    local name = escape(entry.name)
    if linked and present(entry.url) then
      name = external_link(entry.url, name, nil)
    end
    items[#items + 1] = table.concat({
      '<li class="panel-item">',
      '<h3 class="panel-item-name">', name, "</h3>",
      '<p class="panel-item-description">', escape(entry.description), "</p>",
      "</li>",
    })
  end
  return table.concat({
    '<article class="panel-card panel-card--' .. variant .. '">',
    disclosure(label, #rows, label,
      '<ol class="panel-list">' .. table.concat(items, "") .. "</ol>",
      "disclosure--panel"),
    "</article>",
  })
end

return {
  ["lab-projects"] = function(args, kwargs, meta)
    local want = text(args[1])
    if want == "" then want = "current" end
    local rows = collect(meta.projects, function(project)
      return text(project.status) == want
    end)
    if #rows == 0 then return pandoc.Null() end
    local html = (want == "planning")
      and panel_card(rows, "planning", "Topics", false)
      or project_cards(rows, meta)
    return pandoc.RawBlock("html", html)
  end,

  ["lab-related"] = function(args, kwargs, meta)
    local rows = collect(meta.related)
    if #rows == 0 then return pandoc.Null() end
    return pandoc.RawBlock("html", panel_card(rows, "related", "Initiatives", true))
  end,

  ["lab-members"] = function(args, kwargs, meta)
    local people = meta.people
    local rows = collect(people and people.members or nil)
    if #rows == 0 then return pandoc.Null() end
    local profiles = {
      { key = "scholar", label = "Google Scholar" },
      { key = "orcid", label = "ORCID" },
      { key = "linkedin", label = "LinkedIn" },
    }
    local out = { '<ul class="member-list">' }
    for _, row in ipairs(rows) do
      local person = row.entry
      local name = text(person.name)
      local links = {}
      for _, profile in ipairs(profiles) do
        if present(person[profile.key]) then
          links[#links + 1] = external_link(
            person[profile.key], profile.label, name, "member-link")
        end
      end
      local role = present(person.role)
        and ('<span class="member-role">' .. escape(person.role) .. "</span>")
        or ""
      out[#out + 1] = table.concat({
        '<li class="member">',
        '<span class="member-name">', escape(name), role, "</span>",
        '<span class="member-university">', escape(person.university), "</span>",
        #links > 0 and ('<span class="member-links">' .. table.concat(links, "") .. "</span>") or "",
        "</li>",
      })
    end
    out[#out + 1] = "</ul>"
    return pandoc.RawBlock("html", table.concat(out, "\n"))
  end,

}
