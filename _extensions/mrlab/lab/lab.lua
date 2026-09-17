--[[
  Methods Research Lab shortcodes.

  The three YAML files in data/ are merged into document metadata by the
  `metadata-files:` key in _quarto.yml. These shortcodes read that metadata and
  emit plain HTML, so the page itself holds no project, person or link data.

  Shortcodes
    {{< lab-projects current >}}   project cards
    {{< lab-projects planning >}}  lighter list of planned work
    {{< lab-related >}}            external initiatives
    {{< lab-members >}}            group members with profile links
    {{< lab-collaborators >}}      flat collaborator list

  Conventions
    - every entry is sorted by its `order` field, lowest first
    - an empty or missing field is simply left out, so an empty `website:`
      hides that button instead of rendering a dead link
    - links to other sites open in a new tab with rel="noopener noreferrer"
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

-- An external link. `hidden` is appended for screen readers so that repeated
-- link text such as "Visit project website" stays distinguishable.
local function external_link(url, label, hidden, class)
  return table.concat({
    '<a class="', class, '" href="', escape(url), '"',
    ' target="_blank" rel="noopener noreferrer">',
    label,
    '<span class="visually-hidden"> — ', escape(hidden), "</span>",
    "</a>",
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
      '" alt="', escape(alt), '" width="48" height="48" loading="lazy">',
    })
  end
  local initial = name:sub(1, 1):upper()
  return table.concat({
    '<span class="project-mark project-mark--monogram" aria-hidden="true">',
    escape(initial), "</span>",
  })
end

local function project_cards(projects)
  local out = { '<div class="project-grid">' }
  for _, row in ipairs(projects) do
    local project = row.entry
    local name = text(project.name)
    out[#out + 1] = '<article class="project-card">'
    out[#out + 1] = '<div class="project-head">'
    out[#out + 1] = project_mark(project)
    out[#out + 1] = '<h3 class="project-name">' .. escape(name) .. "</h3>"
    out[#out + 1] = "</div>"
    out[#out + 1] = '<p class="project-description">' .. escape(project.description) .. "</p>"

    local links = {}
    if present(project.website) then
      links[#links + 1] = external_link(project.website, "Visit project website", name, "project-link")
    end
    if present(project.outputs) then
      links[#links + 1] = external_link(project.outputs, "Publications &amp; presentations", name, "project-link")
    end
    if #links > 0 then
      out[#out + 1] = '<p class="project-links">' .. table.concat(links, "") .. "</p>"
    end
    out[#out + 1] = "</article>"
  end
  out[#out + 1] = "</div>"
  return table.concat(out, "\n")
end

local function planning_list(projects)
  local out = { '<ul class="planning-list">' }
  for _, row in ipairs(projects) do
    local project = row.entry
    out[#out + 1] = table.concat({
      '<li class="planning-item">',
      '<h3 class="planning-name">', escape(project.name), "</h3>",
      '<p class="planning-description">', escape(project.description), "</p>",
      "</li>",
    })
  end
  out[#out + 1] = "</ul>"
  return table.concat(out, "\n")
end

return {
  ["lab-projects"] = function(args, kwargs, meta)
    local want = text(args[1])
    if want == "" then want = "current" end
    local rows = collect(meta.projects, function(project)
      return text(project.status) == want
    end)
    if #rows == 0 then return pandoc.Null() end
    local html = (want == "planning") and planning_list(rows) or project_cards(rows)
    return pandoc.RawBlock("html", html)
  end,

  ["lab-related"] = function(args, kwargs, meta)
    local rows = collect(meta.related)
    if #rows == 0 then return pandoc.Null() end
    local out = { '<div class="related-panel"><dl class="related-list">' }
    for _, row in ipairs(rows) do
      local item = row.entry
      local name = escape(item.name)
      local heading = name
      if present(item.url) then
        heading = table.concat({
          '<a href="', escape(item.url), '" target="_blank" rel="noopener noreferrer">',
          name, "</a>",
        })
      end
      out[#out + 1] = '<dt class="related-name">' .. heading .. "</dt>"
      out[#out + 1] = '<dd class="related-description">' .. escape(item.description) .. "</dd>"
    end
    out[#out + 1] = "</dl></div>"
    return pandoc.RawBlock("html", table.concat(out, "\n"))
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
      out[#out + 1] = '<li class="member">'
      out[#out + 1] = '<span class="member-name">' .. escape(name) .. "</span>"
      out[#out + 1] = '<span class="member-university">' .. escape(person.university) .. "</span>"
      local links = {}
      for _, profile in ipairs(profiles) do
        if present(person[profile.key]) then
          links[#links + 1] = external_link(person[profile.key], profile.label, name, "member-link")
        end
      end
      if #links > 0 then
        out[#out + 1] = '<span class="member-links">' .. table.concat(links, "") .. "</span>"
      end
      out[#out + 1] = "</li>"
    end
    out[#out + 1] = "</ul>"
    return pandoc.RawBlock("html", table.concat(out, "\n"))
  end,

  ["lab-collaborators"] = function(args, kwargs, meta)
    local people = meta.people
    local rows = collect(people and people.collaborators or nil)
    if #rows == 0 then return pandoc.Null() end
    local out = { '<ul class="collaborator-list">' }
    for _, row in ipairs(rows) do
      local person = row.entry
      out[#out + 1] = table.concat({
        '<li class="collaborator">',
        '<span class="collaborator-name">', escape(person.name), "</span>",
        '<span class="collaborator-university">', escape(person.university), "</span>",
        "</li>",
      })
    end
    out[#out + 1] = "</ul>"
    return pandoc.RawBlock("html", table.concat(out, "\n"))
  end,
}
