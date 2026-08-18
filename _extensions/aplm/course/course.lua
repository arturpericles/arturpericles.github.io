-- Shared course components for an APLM Quarto course subsite.
--
-- The extension keeps semantic content in a canonical syllabus Markdown file
-- and a readable Markdown schedule. Empty Div placeholders in website pages
-- request richer views of the same source material.

local stringify = pandoc.utils.stringify
local script_dir = (PANDOC_SCRIPT_FILE or ""):match("^(.*)[/\\][^/\\]+$") or "."
local calendar = dofile(script_dir .. "/calendar.lua")

local state = {
  meta = nil,
  materials = nil,
  materials_by_shorthand = nil,
  schedule = nil,
  meetings_by_id = nil,
  policies = nil,
  shared_sections = nil,
  source_doc = nil,
  calendar = nil,
  is_html = false,
}

local RESERVED_FIELDS = {
  ["activity"] = true,
  ["additional"] = true,
  ["assignment"] = true,
  ["counts-as-class"] = true,
  ["date"] = true,
  ["note"] = true,
  ["on-deck"] = true,
  ["optional"] = true,
  ["page"] = true,
  ["rescheduled-to"] = true,
  ["room"] = true,
  ["time"] = true,
  ["topic"] = true,
  ["type"] = true,
}

local NONCOUNTING_TYPES = {
  ["cancelled"] = true,
  ["canceled"] = true,
  ["holiday"] = true,
  ["no-class"] = true,
  ["schedule-note"] = true,
}

local HIDDEN_SCHEDULE_FIELDS = {
  ["counts-as-class"] = true,
  ["date"] = true,
  ["on-deck"] = true,
  ["page"] = true,
  ["topic"] = true,
  ["type"] = true,
}

local function fail(message)
  io.stderr:write("aplm-course: " .. message .. "\n")
  io.stderr:flush()
  os.exit(1)
end

local function ptype(value)
  if value == nil then return "nil" end
  return pandoc.utils.type(value)
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(value)
  return trim(value):lower():gsub("[%s_]+", "-"):gsub("%-+", "-")
end

local function meta_string(value)
  if value == nil then return "" end
  return trim(stringify(value))
end

local function meta_boolean(value, default)
  if value == nil then return default end
  if type(value) == "boolean" then return value end
  local text = normalize(stringify(value))
  if text == "true" or text == "yes" or text == "1" then return true end
  if text == "false" or text == "no" or text == "0" then return false end
  fail("expected a boolean value, found " .. stringify(value))
end

local function clone_inlines(inlines)
  local result = pandoc.Inlines({})
  for _, inline in ipairs(inlines or {}) do
    result:insert(inline:clone())
  end
  return result
end

local MONTH_ABBREVIATIONS = {
  January = "Jan.",
  February = "Feb.",
  March = "Mar.",
  April = "Apr.",
  May = "May",
  June = "June",
  July = "July",
  August = "Aug.",
  September = "Sept.",
  October = "Oct.",
  November = "Nov.",
  December = "Dec.",
}

local function abbreviated_date(inlines)
  local text = trim(stringify(inlines))
  local weekday, date_text = text:match("^(%a+),%s+(.+)$")
  date_text = date_text or text
  local month, day = date_text:match("^([%a%.]+)%s+(%d+)$")
  if month == nil then return clone_inlines(inlines) end
  local abbreviation = MONTH_ABBREVIATIONS[month:gsub("%.$", "")]
  if abbreviation == nil then return clone_inlines(inlines) end
  local result = pandoc.Inlines({})
  if weekday ~= nil then
    result:insert(pandoc.Str(weekday .. ","))
    result:insert(pandoc.Space())
  end
  result:insert(pandoc.Str(abbreviation))
  result:insert(pandoc.Space())
  result:insert(pandoc.Str(day))
  return result
end

local function clone_blocks(blocks)
  local result = pandoc.Blocks({})
  for _, block in ipairs(blocks or {}) do
    result:insert(block:clone())
  end
  return result
end

local function markdown_blocks(value)
  if value == nil then return pandoc.Blocks({}) end
  if ptype(value) == "Blocks" then return clone_blocks(value) end
  if ptype(value) == "Inlines" then
    return pandoc.Blocks({pandoc.Para(clone_inlines(value))})
  end
  local text = meta_string(value)
  if text == "" then return pandoc.Blocks({}) end
  return pandoc.read(text, "markdown").blocks
end

local function text_inlines(value)
  local blocks = pandoc.read(value or "", "markdown").blocks
  if #blocks > 0 and (blocks[1].t == "Plain" or blocks[1].t == "Para") then
    return clone_inlines(blocks[1].content)
  end
  return pandoc.Inlines({pandoc.Str(value or "")})
end

local function has_class(div, wanted)
  for _, class_name in ipairs(div.classes or {}) do
    if class_name == wanted then return true end
  end
  return false
end

local function trim_leading_spaces(inlines)
  while #inlines > 0 do
    local first = inlines[1]
    if first.t == "Space" or first.t == "SoftBreak" then
      inlines:remove(1)
    else
      break
    end
  end
  return inlines
end

local function citekeys_from_meta(value)
  local keys = {}
  if value == nil then return keys end
  local values = ptype(value) == "List" and value or {value}
  for _, item in ipairs(values) do
    local key = meta_string(item):gsub("^@", "")
    if key:match("^%[.*%]$") then
      fail("citekey must not use bracketed citation syntax: " .. key)
    end
    if key == "" or key:match("%s") then
      fail("invalid citekey: " .. key)
    end
    table.insert(keys, key)
  end
  return keys
end

local function make_cite(keys)
  local citations = pandoc.List({})
  local fallback = pandoc.Inlines({})
  for index, key in ipairs(keys) do
    local citation = pandoc.Citation(key, pandoc.NormalCitation)
    citation.prefix = pandoc.Inlines({})
    citation.suffix = pandoc.Inlines({})
    citations:insert(citation)
    if index > 1 then
      fallback:insert(pandoc.Str(";"))
      fallback:insert(pandoc.Space())
    end
    fallback:insert(pandoc.Str("@" .. key))
  end
  return pandoc.Cite(fallback, citations)
end

local function bibliography_blocks(keys, meta)
  local citeproc_meta = {}
  for key, value in pairs(meta or {}) do citeproc_meta[key] = value end
  citeproc_meta["suppress-bibliography"] = false

  local citation_doc = pandoc.Pandoc(
    {pandoc.Para({make_cite(keys)})},
    citeproc_meta
  )
  local rendered = pandoc.utils.citeproc(citation_doc)
  local blocks = pandoc.Blocks({})
  for _, block in ipairs(rendered.blocks) do
    if block.t == "Div" and block.identifier == "refs" then
      for _, entry in ipairs(block.content) do
        if entry.t == "Div" and has_class(entry, "csl-entry") then
          blocks:extend(clone_blocks(entry.content))
        end
      end
    end
  end
  if #blocks == 0 then
    fail("the selected CSL produced no bibliography entry for " .. table.concat(keys, ", "))
  end
  return blocks
end

local function strip_trailing_period(inlines)
  while #inlines > 0 do
    local last = inlines[#inlines]
    if last.t == "Space" or last.t == "SoftBreak" then
      inlines:remove(#inlines)
    else
      break
    end
  end
  local last = inlines[#inlines]
  if last ~= nil and last.t == "Str" and last.text:match("%.$") then
    last.text = last.text:gsub("%.$", "")
    if last.text == "" then inlines:remove(#inlines) end
  end
end

local function append_short_form(blocks, shorthand)
  if #blocks == 0 then blocks:insert(pandoc.Para({})) end
  local target = blocks[#blocks]
  if target.t ~= "Plain" and target.t ~= "Para" then
    target = pandoc.Para({})
    blocks:insert(target)
  end
  local content = target.content
  strip_trailing_period(content)
  if #content > 0 then content:insert(pandoc.Space()) end
  content:insert(pandoc.Str("(hereinafter"))
  content:insert(pandoc.Space())
  content:insert(pandoc.Str("“"))
  content:insert(pandoc.Strong({pandoc.Str(shorthand)}))
  content:insert(pandoc.Str("”)."))
end

local function parse_materials(meta)
  local materials = {}
  local by_shorthand = {}
  local declared = meta["course-materials"]
  if declared == nil then return materials, by_shorthand end
  if ptype(declared) ~= "List" then
    fail("course-materials must be a YAML list")
  end
  for index, item in ipairs(declared) do
    local shorthand = meta_string(item.shorthand)
    if not shorthand:match("^[A-Z][A-Z0-9_-]*$") then
      fail("invalid material shorthand in item " .. index .. ": " .. shorthand)
    end
    if by_shorthand[shorthand] ~= nil then
      fail("duplicate material shorthand: " .. shorthand)
    end
    local material = {
      shorthand = shorthand,
      citekeys = citekeys_from_meta(item.citekey or item.citekeys),
      citation = item.citation,
      note = item.note,
    }
    if #material.citekeys == 0 and material.citation == nil then
      fail("material " .. shorthand .. " needs citekey, citekeys, or citation")
    end
    table.insert(materials, material)
    by_shorthand[shorthand] = material
  end
  return materials, by_shorthand
end

local function parse_policies_from_meta(meta)
  local policies = {}
  local declared = meta["course-policies"]
  if declared == nil then return policies end
  if ptype(declared) ~= "List" then
    fail("course-policies must be a YAML list")
  end
  for index, policy in ipairs(declared) do
    local policy_id = meta_string(policy.id)
    local title = meta_string(policy.title)
    local summary = markdown_blocks(policy.syllabus or policy.summary)
    if policy_id == "" or title == "" or #summary == 0 then
      fail("course-policies item " .. index .. " needs id, title, and syllabus summary")
    end
    table.insert(policies, {
      id = policy_id,
      title = title,
      summary = summary,
      detail = markdown_blocks(policy.detail),
      rationale = markdown_blocks(policy.rationale),
    })
  end
  return policies
end

local function resolve_source_path(path, meta)
  local candidates = {path}
  local source_dir = meta_string(meta["course-source-dir"])
  if source_dir ~= "" then
    table.insert(candidates, source_dir:gsub("/$", "") .. "/" .. path)
    if quarto ~= nil and quarto.project ~= nil and quarto.project.directory ~= nil then
      table.insert(candidates, pandoc.path.join({
        quarto.project.directory,
        source_dir,
        path,
      }))
    end
  end
  local input = PANDOC_STATE.input_files and PANDOC_STATE.input_files[1] or ""
  local input_dir = input:match("^(.*)/[^/]+$")
  if input_dir ~= nil then table.insert(candidates, input_dir .. "/" .. path) end

  local handle = nil
  local message = nil
  local resolved = path
  for _, candidate in ipairs(candidates) do
    handle, message = io.open(candidate, "r")
    if handle ~= nil then
      resolved = candidate
      break
    end
  end
  if handle == nil then
    fail("cannot read " .. path .. ": " .. (message or "unknown error"))
  end
  local source = handle:read("*a")
  handle:close()
  return resolved, source
end

local function resolve_reference_path(path, source_path)
  if path == "" or path:match("^https?://") then return path end
  local candidates = {path}
  local source_dir = source_path:match("^(.*)/[^/]+$")
  if source_dir ~= nil then
    table.insert(candidates, pandoc.path.join({source_dir, path}))
  end
  if quarto ~= nil and quarto.project ~= nil and quarto.project.directory ~= nil then
    table.insert(candidates, pandoc.path.join({quarto.project.directory, path}))
  end
  for _, resource_dir in ipairs(PANDOC_STATE.resource_path or {}) do
    table.insert(candidates, pandoc.path.join({resource_dir, path}))
  end
  for _, candidate in ipairs(candidates) do
    local handle = io.open(candidate, "r")
    if handle ~= nil then
      handle:close()
      return candidate
    end
  end
  return path
end

local function resolve_reference_meta(meta, key, source_path)
  local value = meta[key]
  if value == nil then return end
  if ptype(value) == "List" then
    local resolved = {}
    for _, item in ipairs(value) do
      table.insert(resolved, resolve_reference_path(meta_string(item), source_path))
    end
    meta[key] = resolved
  else
    meta[key] = resolve_reference_path(meta_string(value), source_path)
  end
end

local function load_course_source(meta)
  local path = meta_string(meta["course-source"])
  if path == "" then return nil end
  local resolved, source = resolve_source_path(path, meta)
  local doc = pandoc.read(
    source,
    "markdown+yaml_metadata_block+fenced_divs+header_attributes"
  )
  resolve_reference_meta(doc.meta, "bibliography", resolved)
  resolve_reference_meta(doc.meta, "csl", resolved)
  return doc
end

local SOURCE_META_KEYS = {
  "affiliation",
  "bibliography",
  "course",
  "course-base-url",
  "course-schedule",
  "course-source-dir",
  "csl",
  "global-template",
  "suppress-bibliography",
  "updated",
}

local function merge_source_meta(meta, source_meta)
  for _, key in ipairs(SOURCE_META_KEYS) do
    if meta[key] == nil and source_meta[key] ~= nil then
      meta[key] = source_meta[key]
    end
  end
end

local function material_from_div(div)
  local shorthand = trim(div.attributes.shorthand or div.identifier or "")
  if not shorthand:match("^[A-Z][A-Z0-9_-]*$") then
    fail("course-material needs an uppercase shorthand attribute")
  end
  local material = {
    shorthand = shorthand,
    citekeys = citekeys_from_meta(div.attributes.citekey or div.attributes.citekeys),
    citation = nil,
    note = clone_blocks(div.content),
  }
  if #material.citekeys == 0 then
    fail("course-material " .. shorthand .. " needs a citekey attribute")
  end
  return material
end

local function policy_from_div(div)
  local policy = {
    id = trim(div.identifier or ""),
    title = "",
    summary = pandoc.Blocks({}),
    detail = pandoc.Blocks({}),
    rationale = pandoc.Blocks({}),
  }
  for _, block in ipairs(div.content) do
    if block.t == "Header" and policy.title == "" then
      policy.title = trim(stringify(block.content))
    elseif block.t == "Div" and has_class(block, "syllabus-summary") then
      policy.summary = clone_blocks(block.content)
    elseif block.t == "Div" and has_class(block, "policy-detail") then
      policy.detail = clone_blocks(block.content)
    elseif block.t == "Div" and has_class(block, "policy-rationale") then
      policy.rationale = clone_blocks(block.content)
    end
  end
  if policy.id == "" or policy.title == "" or #policy.summary == 0 then
    fail("every course-policy needs an id, heading, and {.syllabus-summary}")
  end
  return policy
end

local function parse_course_source(doc)
  local materials = {}
  local materials_by_shorthand = {}
  local policies = {}
  local shared_sections = {}

  local function inspect(blocks)
    for _, block in ipairs(blocks or {}) do
      if block.t == "Div" then
        if has_class(block, "course-share") then
          if block.identifier == "" then fail("course-share Div needs an identifier") end
          shared_sections[block.identifier] = clone_blocks(block.content)
        elseif has_class(block, "course-materials-source") then
          for _, child in ipairs(block.content) do
            if child.t == "Div" and has_class(child, "course-material") then
              local material = material_from_div(child)
              if materials_by_shorthand[material.shorthand] ~= nil then
                fail("duplicate material shorthand: " .. material.shorthand)
              end
              table.insert(materials, material)
              materials_by_shorthand[material.shorthand] = material
            end
          end
        elseif has_class(block, "course-policies-source") then
          for _, child in ipairs(block.content) do
            if child.t == "Div" and has_class(child, "course-policy") then
              table.insert(policies, policy_from_div(child))
            end
          end
        else
          inspect(block.content)
        end
      end
    end
  end
  inspect(doc.blocks)
  return materials, materials_by_shorthand, policies, shared_sections
end

local function material_blocks(material)
  local blocks
  if #material.citekeys > 0 then
    blocks = bibliography_blocks(
      material.citekeys,
      state.source_doc and state.source_doc.meta or state.meta
    )
  else
    blocks = markdown_blocks(material.citation)
  end
  append_short_form(blocks, material.shorthand)
  if material.note ~= nil then
    local note = markdown_blocks(material.note)
    if #note > 0 then
      local note_div = pandoc.Div(note, pandoc.Attr("", {"course-material-note"}))
      blocks:insert(note_div)
    end
  end
  return blocks
end

local function render_materials()
  if #state.materials == 0 then
    fail("course-materials shortcode found, but course-materials metadata is empty")
  end
  local items = {}
  for _, material in ipairs(state.materials) do
    table.insert(items, material_blocks(material))
  end
  return pandoc.Div(
    {pandoc.BulletList(items)},
    pandoc.Attr("", {"course-materials-list"})
  )
end

local function parse_field_item(item)
  if #item == 0 then return nil end
  local first = item[1]
  if first.t ~= "Plain" and first.t ~= "Para" then return nil end
  local inlines = clone_inlines(first.content)
  if #inlines == 0 or inlines[1].t ~= "Str" then return nil end
  local label = inlines[1].text:match("^([^:]+):$")
  if label == nil then return nil end
  inlines:remove(1)
  trim_leading_spaces(inlines)
  local blocks = pandoc.Blocks({})
  blocks:insert(first.t == "Para" and pandoc.Para(inlines) or pandoc.Plain(inlines))
  for index = 2, #item do blocks:insert(item[index]:clone()) end
  return {
    label = label,
    normalized = normalize(label),
    blocks = blocks,
  }
end

local function field_text(meeting, name)
  local fields = meeting.by_name[name]
  if fields == nil or fields[1] == nil then return "" end
  return trim(stringify(fields[1].blocks))
end

local function meeting_counts(meeting)
  local explicit = normalize(field_text(meeting, "counts-as-class"))
  if explicit ~= "" then
    if explicit == "yes" or explicit == "true" or explicit == "1" then return true end
    if explicit == "no" or explicit == "false" or explicit == "0" then return false end
    fail("counts-as-class must be yes/no or true/false for " .. stringify(meeting.date))
  end
  return not NONCOUNTING_TYPES[normalize(field_text(meeting, "type"))]
end

local function on_deck_group_count(course)
  if course == nil then return 0 end
  local text = meta_string(course["on-deck-groups"])
  if text == "" then return 0 end
  local count = tonumber(text)
  if count == nil or count < 1 or count ~= math.floor(count) then
    fail("course.on-deck-groups must be a positive integer")
  end
  return count
end

local function meeting_is_on_deck(meeting)
  if not meeting_counts(meeting) then return false end
  local explicit = normalize(field_text(meeting, "on-deck"))
  if explicit == "" or explicit == "yes" or explicit == "true" or explicit == "1" then
    return true
  end
  if explicit == "no" or explicit == "false" or explicit == "0" then return false end
  fail("on-deck must be yes/no or true/false for " .. stringify(meeting.date))
end

local function parse_meeting(heading, blocks, generated_dates)
  local meeting = {
    id = heading.identifier,
    date = generated_dates and nil or abbreviated_date(heading.content),
    topic = pandoc.Blocks({}),
    fields = {},
    by_name = {},
  }
  if meeting.id == "" then
    fail("every schedule meeting heading needs an explicit stable identifier")
  end
  for _, block in ipairs(blocks) do
    if block.t == "BulletList" then
      for _, item in ipairs(block.content) do
        local field = parse_field_item(item)
        if field == nil then
          fail("schedule items under " .. stringify(heading.content) .. " must begin with a label such as CB: or assignment:")
        end
        local material = state.materials_by_shorthand[field.label]
        if material == nil and not RESERVED_FIELDS[field.normalized] then
          fail("unknown schedule label '" .. field.label .. "' under " .. stringify(heading.content))
        end
        field.material = material
        table.insert(meeting.fields, field)
        meeting.by_name[field.normalized] = meeting.by_name[field.normalized] or {}
        table.insert(meeting.by_name[field.normalized], field)
      end
    elseif generated_dates then
      fail("generated-date meeting '" .. stringify(heading.content)
        .. "' may contain only labeled list items beneath its heading")
    else
      meeting.topic:insert(block:clone())
    end
  end
  local explicit_topic = meeting.by_name.topic and meeting.by_name.topic[1]
  if generated_dates then
    if explicit_topic ~= nil then
      fail("generated-date meeting '" .. stringify(heading.content)
        .. "' must use its heading as the topic, not a topic: field")
    end
    meeting.topic = pandoc.Blocks({pandoc.Plain(clone_inlines(heading.content))})
  elseif explicit_topic ~= nil then
    if #meeting.topic > 0 then
      fail("meeting " .. stringify(heading.content) .. " has both a topic paragraph and topic: field")
    end
    meeting.topic = clone_blocks(explicit_topic.blocks)
  end
  if #meeting.topic == 0 then
    fail("meeting " .. stringify(heading.content) .. " needs a topic paragraph")
  end
  return meeting
end

local function read_schedule_source()
  local path = meta_string(state.meta["course-schedule"])
  if path == "" then fail("course-schedule metadata is required") end
  local candidates = {path}
  local source_dir = meta_string(state.meta["course-source-dir"])
  if source_dir ~= "" then
    table.insert(candidates, source_dir:gsub("/$", "") .. "/" .. path)
    if quarto ~= nil and quarto.project ~= nil and quarto.project.directory ~= nil then
      table.insert(candidates, pandoc.path.join({
        quarto.project.directory,
        source_dir,
        path,
      }))
    end
  end
  local input = PANDOC_STATE.input_files and PANDOC_STATE.input_files[1] or ""
  local input_dir = input:match("^(.*)/[^/]+$")
  if input_dir ~= nil then table.insert(candidates, input_dir .. "/" .. path) end

  local handle = nil
  local message = nil
  local resolved = path
  for _, candidate in ipairs(candidates) do
    handle, message = io.open(candidate, "r")
    if handle ~= nil then
      resolved = candidate
      break
    end
  end
  if handle == nil then
    fail("cannot read " .. path .. ": " .. (message or "unknown error"))
  end
  local source = handle:read("*a")
  handle:close()
  return pandoc.read(source, "markdown+fenced_divs+header_attributes").blocks
end

local function unit_title(inlines, unit_number)
  if unit_number == nil then return clone_inlines(inlines) end
  local title = pandoc.Inlines({
    pandoc.Str("Unit"),
    pandoc.Space(),
    pandoc.Str(tostring(unit_number)),
    pandoc.Space(),
    pandoc.Str("—"),
    pandoc.Space(),
  })
  for _, inline in ipairs(inlines) do title:insert(inline:clone()) end
  return title
end

local function load_schedule()
  if state.schedule ~= nil then return state.schedule end
  local units = {}
  local meetings_by_id = {}
  local unit_number = 0
  local date_allocator = calendar.new_allocator(state.calendar, fail)
  local current_unit = nil
  local current_heading = nil
  local current_blocks = pandoc.Blocks({})

  local function finish_meeting()
    if current_heading == nil then return end
    if current_unit == nil then fail("meeting appears before its level-three unit heading") end
    local meeting = parse_meeting(current_heading, current_blocks, date_allocator ~= nil)
    if date_allocator ~= nil then
      local entry_type = field_text(meeting, "type")
      local assigned = date_allocator:assign(
        field_text(meeting, "date"),
        "meeting '" .. stringify(meeting.topic) .. "'",
        {
          fixed_regular_date = calendar.is_fixed_closure_type(entry_type),
          entry_type = entry_type,
        }
      )
      meeting.date = calendar.website_inlines(assigned)
    end
    if meetings_by_id[meeting.id] ~= nil then fail("duplicate meeting id: " .. meeting.id) end
    table.insert(current_unit.meetings, meeting)
    meetings_by_id[meeting.id] = meeting
    current_heading = nil
    current_blocks = pandoc.Blocks({})
  end

  for _, block in ipairs(read_schedule_source()) do
    if block.t == "Header" and block.level == 3 then
      finish_meeting()
      local numbered = not has_class(block, "unnumbered")
      if numbered then unit_number = unit_number + 1 end
      current_unit = {
        id = block.identifier,
        title = unit_title(block.content, numbered and unit_number or nil),
        meetings = {},
      }
      table.insert(units, current_unit)
    elseif block.t == "Header" and block.level == 4 then
      finish_meeting()
      current_heading = block
      current_blocks = pandoc.Blocks({})
    elseif current_heading ~= nil then
      current_blocks:insert(block:clone())
    elseif block.t ~= "Null" then
      fail("schedule content must appear beneath a level-four meeting heading")
    end
  end
  finish_meeting()
  if date_allocator ~= nil then date_allocator:finish() end

  local class_number = 0
  local on_deck_index = 0
  local on_deck_groups = on_deck_group_count(state.meta.course)
  for _, unit in ipairs(units) do
    for _, meeting in ipairs(unit.meetings) do
      if meeting_counts(meeting) then
        class_number = class_number + 1
        meeting.class_number = class_number
      end
      if on_deck_groups > 0 and meeting_is_on_deck(meeting) then
        on_deck_index = on_deck_index + 1
        meeting.on_deck_group = ((on_deck_index - 1) % on_deck_groups) + 1
      end
    end
  end
  state.schedule = units
  state.meetings_by_id = meetings_by_id
  return units
end

local function inline_link_for_topic(meeting)
  local topic = clone_blocks(meeting.topic)
  local page = field_text(meeting, "page")
  if page == "" then return topic end
  local base = meta_string(state.meta["course-base-url"])
  if base == "" then base = "/teaching/torts/" end
  if not base:match("/$") then base = base .. "/" end
  page = page:gsub("^/", "")
  local first = topic[1]
  if first and (first.t == "Plain" or first.t == "Para") then
    first.content = pandoc.Inlines({pandoc.Link(clone_inlines(first.content), base .. page)})
  end
  return topic
end

local function field_display_name(field)
  if field.material ~= nil then return field.material.shorthand end
  local labels = {
    ["activity"] = "Activity",
    ["note"] = "Note",
    ["rescheduled-to"] = "Rescheduled to",
    ["room"] = "Room",
    ["time"] = "Time",
  }
  return labels[field.normalized] or field.label
end

local function run_in_label(blocks, label, style)
  local result = clone_blocks(blocks)
  if #result == 0 then result:insert(pandoc.Plain({})) end
  local first = result[1]
  if first.t ~= "Plain" and first.t ~= "Para" then
    first = pandoc.Plain({})
    result:insert(1, first)
  end
  local label_text = pandoc.Inlines({pandoc.Str(label .. ":")})
  local label_inline
  if style == "italic" then
    label_inline = pandoc.Emph(label_text)
  elseif style == "strong-italic" then
    label_inline = pandoc.Strong({pandoc.Emph(label_text)})
  else
    label_inline = pandoc.Strong(label_text)
  end
  local content = pandoc.Inlines({label_inline})
  if #first.content > 0 then content:insert(pandoc.Space()) end
  for _, inline in ipairs(first.content) do content:insert(inline:clone()) end
  first.content = content
  return result
end

local function optional_field_item(fields)
  if #fields == 1 then
    return run_in_label(fields[1].blocks, "Optional", "italic")
  end
  local readings = {}
  for _, field in ipairs(fields) do
    table.insert(readings, clone_blocks(field.blocks))
  end
  return pandoc.Blocks({
    pandoc.Plain({pandoc.Emph({pandoc.Str("Optional:")})}),
    pandoc.BulletList(readings),
  })
end

local function assignment_field_item(fields)
  if #fields == 1 then
    return run_in_label(fields[1].blocks, "Assignment", "strong-italic")
  end
  local assignments = {}
  for _, field in ipairs(fields) do
    table.insert(assignments, clone_blocks(field.blocks))
  end
  return pandoc.Blocks({
    pandoc.Plain({pandoc.Strong({
      pandoc.Emph({pandoc.Str("Assignments:")}),
    })}),
    pandoc.BulletList(assignments),
  })
end

local function render_fields(meeting)
  local items = {}
  local optional_rendered = false
  local assignment_rendered = false
  for _, field in ipairs(meeting.fields) do
    if not HIDDEN_SCHEDULE_FIELDS[field.normalized] then
      if field.normalized == "additional" then
        table.insert(items, clone_blocks(field.blocks))
      elseif field.normalized == "optional" then
        if not optional_rendered then
          table.insert(items, optional_field_item(meeting.by_name.optional))
          optional_rendered = true
        end
      elseif field.normalized == "assignment" then
        if not assignment_rendered then
          table.insert(items, assignment_field_item(meeting.by_name.assignment))
          assignment_rendered = true
        end
      else
        table.insert(items, run_in_label(
          field.blocks,
          field_display_name(field),
          "strong"
        ))
      end
    end
  end
  if #items == 0 then return nil end
  return pandoc.BulletList(items)
end

local function render_meeting(meeting)
  local blocks = pandoc.Blocks({})
  local kicker = pandoc.Inlines({})
  if meeting.class_number ~= nil then
    kicker:insert(pandoc.Str("Class"))
    kicker:insert(pandoc.Space())
    kicker:insert(pandoc.Str(tostring(meeting.class_number)))
    kicker:insert(pandoc.Space())
    kicker:insert(pandoc.Str("·"))
    kicker:insert(pandoc.Space())
  end
  for _, inline in ipairs(meeting.date) do kicker:insert(inline:clone()) end
  if meeting.on_deck_group ~= nil then
    kicker:insert(pandoc.Span({
      pandoc.Str("On"),
      pandoc.Space(),
      pandoc.Str("deck:"),
      pandoc.Space(),
      pandoc.Str("Panel"),
      pandoc.Space(),
      pandoc.Str(tostring(meeting.on_deck_group)),
    }, pandoc.Attr("", {"course-meeting-on-deck"})))
  end
  blocks:insert(pandoc.Div(
    {pandoc.Para(kicker)},
    pandoc.Attr("", {"course-meeting-kicker"})
  ))

  local topic = inline_link_for_topic(meeting)
  if #topic > 0 then
    local first = topic[1]
    if first.t == "Plain" or first.t == "Para" then
      blocks:insert(pandoc.Header(
        3,
        clone_inlines(first.content),
        pandoc.Attr(meeting.id .. "-topic", {}, {})
      ))
      for index = 2, #topic do blocks:insert(topic[index]:clone()) end
    else
      for _, block in ipairs(topic) do blocks:insert(block:clone()) end
    end
  end

  local meeting_type = normalize(field_text(meeting, "type"))
  if meeting_type ~= "" then
    local status = meeting_type:gsub("%-", " ")
    status = status:gsub("^%l", string.upper)
    blocks:insert(pandoc.Div(
      {pandoc.Para({pandoc.Str(status)})},
      pandoc.Attr("", {"course-meeting-status"})
    ))
  end

  local fields = render_fields(meeting)
  if fields ~= nil then blocks:insert(fields) end
  local classes = {"course-meeting"}
  if meeting.class_number == nil then table.insert(classes, "course-meeting-noncounting") end
  return pandoc.Div(blocks, pandoc.Attr(meeting.id, classes))
end

local function render_schedule()
  local output = pandoc.Blocks({})
  for _, unit in ipairs(load_schedule()) do
    output:insert(pandoc.Header(2, clone_inlines(unit.title), pandoc.Attr(unit.id, {}, {})))
    local cards = pandoc.Blocks({})
    for _, meeting in ipairs(unit.meetings) do cards:insert(render_meeting(meeting)) end
    output:insert(pandoc.Div(cards, pandoc.Attr("", {"course-meeting-grid"})))
  end
  return output
end

local function render_policies()
  local policies = state.policies or {}
  if #policies == 0 then
    fail("course-policies placeholder found, but the course source has no policies")
  end
  local output = pandoc.Blocks({})
  for _, policy in ipairs(policies) do
    local policy_id = policy.id
    local title = policy.title
    if policy_id == "" or title == "" then fail("every policy needs id and title") end
    output:insert(pandoc.Header(
      2,
      text_inlines(title),
      pandoc.Attr(policy_id, {"course-policy"}, {})
    ))

    local summary = clone_blocks(policy.summary)
    if #summary == 0 then fail("policy " .. policy_id .. " needs syllabus or summary") end
    output:insert(pandoc.Div(summary, pandoc.Attr("", {"course-policy-summary"})))

    local detail = clone_blocks(policy.detail)
    if #detail > 0 then
      output:insert(pandoc.Div(detail, pandoc.Attr("", {"course-policy-detail"})))
    end

    local rationale = clone_blocks(policy.rationale)
    if #rationale > 0 then
      local rationale_blocks = pandoc.Blocks({
        pandoc.Header(
          3,
          {pandoc.Str("Why this policy exists")},
          pandoc.Attr(policy_id .. "-rationale", {}, {})
        )
      })
      for _, block in ipairs(rationale) do rationale_blocks:insert(block:clone()) end
      output:insert(pandoc.Div(rationale_blocks, pandoc.Attr("", {"course-policy-rationale"})))
    end
  end
  return output
end

local function render_shared_section(section_id)
  local source = state.shared_sections and state.shared_sections[section_id]
  if source == nil then fail("unknown shared course section: " .. section_id) end
  local blocks = clone_blocks(source)
  return blocks:walk({
    Header = function(header)
      header.level = math.min(header.level + 1, 6)
      return header
    end,
  })
end

local function render_facts()
  local course = state.meta.course
  if course == nil then fail("course metadata is required") end
  local candidates = {
    {"School", course.school},
    {"Term", course.term},
    {"Instructor", course.instructor},
    {"Meetings", course.meetings},
    {"Location", course.location},
    {"Office hours", course["office-hours"]},
  }
  local blocks = pandoc.Blocks({})
  for _, candidate in ipairs(candidates) do
    local value = meta_string(candidate[2])
    if value ~= "" then
      blocks:insert(pandoc.Div({
        pandoc.Para({pandoc.Str(candidate[1])}),
        pandoc.Para(markdown_blocks(candidate[2])[1].content),
      }, pandoc.Attr("", {"course-fact"})))
    end
  end
  return pandoc.Div(blocks, pandoc.Attr("", {"course-facts-grid"}))
end

local function render_class_preparation(meeting_id)
  load_schedule()
  local meeting = state.meetings_by_id[meeting_id]
  if meeting == nil then fail("unknown meeting id for class-preparation: " .. meeting_id) end
  local blocks = pandoc.Blocks({})
  local label = meeting.class_number and ("Class " .. meeting.class_number) or "Schedule note"
  blocks:insert(pandoc.Div({pandoc.Para({
    pandoc.Strong({pandoc.Str(label)}),
    pandoc.Space(),
    pandoc.Str("·"),
    pandoc.Space(),
    table.unpack(clone_inlines(meeting.date)),
  })}, pandoc.Attr("", {"course-meeting-kicker"})))
  blocks:insert(pandoc.Header(
    2,
    {pandoc.Str("Preparation")},
    pandoc.Attr(meeting.id .. "-preparation", {}, {})
  ))
  local fields = render_fields(meeting)
  if fields ~= nil then blocks:insert(fields) end
  return pandoc.Div(blocks, pandoc.Attr("", {"class-preparation-rendered"}))
end

local function course_context(meta)
  local course = meta.course
  if course == nil then return "" end

  local parts = {}
  if meta_boolean(meta["course-overview"], false) then
    local school = meta_string(meta.school)
    if school == "" then school = meta_string(course.school) end
    if school ~= "" then table.insert(parts, school) end

    local instructor = meta_string(meta.instructor)
    if instructor == "" then instructor = meta_string(course.instructor) end
    if instructor ~= "" then table.insert(parts, instructor) end
  else
    local title = meta_string(course.title)
    if title ~= "" then table.insert(parts, title) end
  end

  local term = meta_string(course.term)
  if term ~= "" then table.insert(parts, term) end

  return table.concat(parts, " · ")
end

local function initialize(meta)
  state.is_html = meta_boolean(meta["course-site"], false)
    and FORMAT:match("html") ~= nil
  state.meta = meta
  state.source_doc = nil
  state.shared_sections = {}
  state.policies = {}

  if state.is_html then
    state.source_doc = load_course_source(meta)
    if state.source_doc ~= nil then
      merge_source_meta(meta, state.source_doc.meta)
      state.materials,
        state.materials_by_shorthand,
        state.policies,
        state.shared_sections = parse_course_source(state.source_doc)
    else
      state.materials, state.materials_by_shorthand = parse_materials(meta)
      state.policies = parse_policies_from_meta(meta)
    end
  else
    state.materials, state.materials_by_shorthand = {}, {}
  end

  state.schedule = nil
  state.meetings_by_id = nil
  state.calendar = calendar.configure(meta.course, fail)
  if meta_boolean(meta["course-site"], false) and state.is_html then
    quarto.doc.add_html_dependency({
      name = "aplm-course",
      version = "0.4.1",
      stylesheets = {"course.css"},
    })
  end
  local context = course_context(meta)
  if context ~= "" then meta.subtitle = text_inlines(context) end
  return meta
end

local function replace_placeholder(div)
  if not state.is_html then return nil end
  if has_class(div, "course-section") then
    return render_shared_section(div.attributes.source or div.identifier or "")
  end
  if has_class(div, "course-facts") then return render_facts() end
  if has_class(div, "course-materials") then return render_materials() end
  if has_class(div, "course-policies") then return render_policies() end
  if has_class(div, "course-schedule") then return render_schedule() end
  if has_class(div, "class-preparation") then
    return render_class_preparation(div.attributes["meeting-id"] or "")
  end
end

return {
  { Meta = initialize },
  { Div = replace_placeholder },
}
