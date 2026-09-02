-- Generate a syllabus schedule from readable, structured Markdown.
--
-- Authoring contract:
--   * Semantic Divs in the syllabus declare materials and policies outside YAML.
--   * Under "Schedule", level-three headings introduce units,
--     level-four headings supply topics; dates come from structured course metadata.
--   * Plain labeled list items (for example, "CB: 1-12") provide readings
--     and meeting metadata. The filter, not the source Markdown, adds styling.

local stringify = pandoc.utils.stringify
local script_dir = (PANDOC_SCRIPT_FILE or ""):match("^(.*)[/\\][^/\\]+$") or "."
local calendar = dofile(script_dir .. "/calendar.lua")

local function ptype(value)
  if value == nil then return "nil" end
  return pandoc.utils.type(value)
end

local RESERVED_FIELDS = {
  ["activity"] = true,
  ["additional"] = true,
  ["assignment"] = true,
  ["attendance"] = true,
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
  ["ta-session"] = true,
}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(value)
  return trim(value):lower():gsub("[%s_]+", "-"):gsub("%-+", "-")
end

local function fail(message)
  io.stderr:write("syllabus-schedule: " .. message .. "\n")
  io.stderr:flush()
  os.exit(1)
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

local WEEKDAY_ABBREVIATIONS = {
  Sunday = "Su",
  Monday = "M",
  Tuesday = "Tu",
  Wednesday = "W",
  Thursday = "Th",
  Friday = "F",
  Saturday = "Sa",
}

local function compact_date(inlines)
  local text = trim(stringify(inlines))
  local weekday, date_text = text:match("^(%a+),%s+(.+)$")
  date_text = date_text or text
  local month, day = date_text:match("^([%a%.]+)%s+(%d+)$")
  if month == nil then return clone_inlines(inlines) end
  local month_abbreviation = MONTH_ABBREVIATIONS[month:gsub("%.$", "")]
  if month_abbreviation == nil then return clone_inlines(inlines) end
  local result = pandoc.Inlines({
    pandoc.Str(month_abbreviation),
    pandoc.Space(),
    pandoc.Str(day),
  })
  local weekday_abbreviation = WEEKDAY_ABBREVIATIONS[weekday]
  if weekday_abbreviation ~= nil then
    result:insert(pandoc.Space())
    result:insert(pandoc.Str("(" .. weekday_abbreviation .. ")"))
  end
  return result
end

local function clone_blocks(blocks)
  local result = pandoc.Blocks({})
  for _, block in ipairs(blocks or {}) do
    result:insert(block:clone())
  end
  return result
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

local function markdown_blocks(value)
  if value == nil then
    return pandoc.Blocks({})
  end
  if ptype(value) == "Blocks" then
    return clone_blocks(value)
  end
  if ptype(value) == "Inlines" then
    return pandoc.Blocks({pandoc.Plain(clone_inlines(value))})
  end
  local text = trim(stringify(value))
  if text == "" then
    return pandoc.Blocks({})
  end
  return pandoc.read(text, "markdown").blocks
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

local function append_short_form(blocks, shorthand, note)
  if #blocks == 0 then
    blocks:insert(pandoc.Plain({}))
  end
  local target = blocks[#blocks]
  if target.t ~= "Plain" and target.t ~= "Para" then
    target = pandoc.Para({})
    blocks:insert(target)
  end
  strip_trailing_period(target.content)
  target.content:insert(pandoc.Space())
  target.content:insert(pandoc.Str("(hereinafter"))
  target.content:insert(pandoc.Space())
  target.content:insert(pandoc.Str("“"))
  target.content:insert(pandoc.Strong({pandoc.Str(shorthand)}))
  target.content:insert(pandoc.Str("”)."))
  if note ~= nil then
    local note_blocks = markdown_blocks(note)
    if #note_blocks > 0 then
      local note_inlines = note_blocks[1].content
      target.content:insert(pandoc.Space())
      for _, inline in ipairs(note_inlines) do
        target.content:insert(inline:clone())
      end
    end
  end
end

local function meta_string(value)
  if value == nil then
    return ""
  end
  return trim(stringify(value))
end

local function meta_boolean(value, default)
  if value == nil then return default end
  if type(value) == "boolean" then return value end
  local text = normalize(stringify(value))
  if text == "true" or text == "yes" or text == "1" then return true end
  if text == "false" or text == "no" or text == "0" then return false end
  fail("boolean metadata value must be true/false or yes/no: " .. stringify(value))
end

local function citekeys_from_meta(value)
  local keys = {}
  if value == nil then
    return keys
  end
  local values = ptype(value) == "List" and value or {value}
  for _, item in ipairs(values) do
    local key = meta_string(item)
    key = key:gsub("^@", "")
    if key:match("^%[.*%]$") then
      fail("citekey must be semantic data, not bracketed citation syntax: " .. key)
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
        if entry.t == "Div" then
          for _, class_name in ipairs(entry.classes or {}) do
            if class_name == "csl-entry" then
              blocks:extend(clone_blocks(entry.content))
              break
            end
          end
        end
      end
    end
  end
  if #blocks == 0 then
    fail("the selected CSL produced no bibliography entry for " .. table.concat(keys, ", "))
  end
  return blocks
end

local function parse_materials(meta)
  local declared = meta["course-materials"]
  local materials = {}
  local by_shorthand = {}
  if declared == nil then
    return materials, by_shorthand
  end
  if ptype(declared) ~= "List" then
    fail("course-materials must be a YAML list")
  end
  for index, item in ipairs(declared) do
    if type(item) ~= "table" then
      fail("course-materials item " .. index .. " must be a YAML mapping")
    end
    local shorthand = meta_string(item.shorthand)
    if not shorthand:match("^[A-Z][A-Z0-9_-]*$") then
      fail("material shorthand must begin with an uppercase letter and contain only A-Z, 0-9, _ or -: " .. shorthand)
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

local function material_list(materials, meta)
  local items = {}
  for _, material in ipairs(materials) do
    local blocks
    if #material.citekeys > 0 then
      blocks = bibliography_blocks(material.citekeys, meta)
    else
      blocks = markdown_blocks(material.citation)
    end
    append_short_form(blocks, material.shorthand, material.note)
    table.insert(items, blocks)
  end
  return pandoc.BulletList(items)
end

local function has_class(attr, wanted)
  for _, class in ipairs(attr.classes or {}) do
    if class == wanted then
      return true
    end
  end
  return false
end

local function strip_source_positions(blocks)
  -- Quarto's source-position reader wraps source blocks in transparent Divs.
  -- Remove those wrappers before applying the semantic authoring contract.
  return blocks:walk({
    Div = function(div)
      if div.attributes["data-pos"] ~= nil then return div.content end
    end,
  })
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

local function replace_course_material_sources(blocks, meta)
  local materials = {}
  local by_shorthand = {}
  local replacements = 0
  local walked = blocks:walk({
    Div = function(div)
      if not has_class(div.attr, "course-materials-source") then return nil end
      for _, child in ipairs(div.content) do
        if child.t == "Div" and has_class(child.attr, "course-material") then
          local material = material_from_div(child)
          if by_shorthand[material.shorthand] ~= nil then
            fail("duplicate material shorthand: " .. material.shorthand)
          end
          table.insert(materials, material)
          by_shorthand[material.shorthand] = material
        end
      end
      if #materials == 0 then fail("course-materials-source contains no materials") end
      replacements = replacements + 1
      return material_list(materials, meta)
    end,
  })
  return walked, materials, by_shorthand, replacements
end

local function policy_summary_item(div)
  local title = ""
  local summary = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    if block.t == "Header" and title == "" then
      title = trim(stringify(block.content))
    elseif block.t == "Div" and has_class(block.attr, "syllabus-summary") then
      summary = clone_blocks(block.content)
    end
  end
  if div.identifier == "" or title == "" or #summary == 0 then
    fail("every course-policy needs an id, heading, and {.syllabus-summary}")
  end
  local first = summary[1]
  if first.t ~= "Plain" and first.t ~= "Para" then
    first = pandoc.Para({pandoc.Str(stringify(first))})
    summary[1] = first
  end
  local content = pandoc.Inlines({pandoc.Strong({pandoc.Str(title .. ".")})})
  if #first.content > 0 then content:insert(pandoc.Space()) end
  for _, inline in ipairs(first.content) do content:insert(inline:clone()) end
  first.content = content
  return summary
end

local function policy_full_blocks(div)
  local title = nil
  local summary = pandoc.Blocks({})
  local detail = pandoc.Blocks({})
  local rationale = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    if block.t == "Header" and title == nil then
      title = block:clone()
    elseif block.t == "Div" and has_class(block.attr, "syllabus-summary") then
      summary = clone_blocks(block.content)
    elseif block.t == "Div" and has_class(block.attr, "policy-detail") then
      detail = clone_blocks(block.content)
    elseif block.t == "Div" and has_class(block.attr, "policy-rationale") then
      rationale = clone_blocks(block.content)
    end
  end
  if div.identifier == "" or title == nil or #summary == 0 then
    fail("every course-policy needs an id, heading, and {.syllabus-summary}")
  end

  -- Reserve enough room for the policy heading, summary, and its concise
  -- operational statement. Policies without a detail block need less room.
  -- A rationale remains outside this reservation and may flow independently.
  local required_space = #detail > 0 and "12\\baselineskip" or "5\\baselineskip"
  local output = pandoc.Blocks({
    pandoc.RawBlock("latex", "\\Needspace{" .. required_space .. "}"),
    title,
  })
  for _, block in ipairs(summary) do
    if block.t == "Plain" or block.t == "Para" then
      block.content = pandoc.Inlines({pandoc.Emph(clone_inlines(block.content))})
      output:insert(block)
    else
      output:insert(pandoc.Para({pandoc.Emph({pandoc.Str(stringify(block))})}))
    end
  end
  if #detail > 0 then
    output:extend(detail)
  end
  if #rationale > 0 then
    output:insert(pandoc.Header(
      title.level + 1,
      {pandoc.Str("Why this policy exists")},
      pandoc.Attr(div.identifier .. "-rationale")
    ))
    output:extend(rationale)
  end
  return output
end

local function replace_course_policy_sources(blocks, display)
  local replacements = 0
  local walked = blocks:walk({
    Div = function(div)
      if not has_class(div.attr, "course-policies-source") then return nil end
      local output = pandoc.Blocks({})
      local items = {}
      for _, child in ipairs(div.content) do
        if child.t == "Div" and has_class(child.attr, "course-policy") then
          if display == "full" then
            output:extend(policy_full_blocks(child))
          else
            table.insert(items, policy_summary_item(child))
          end
        end
      end
      if display == "full" and #output == 0 then
        fail("course-policies-source contains no policies")
      elseif display ~= "full" and #items == 0 then
        fail("course-policies-source contains no policies")
      end
      replacements = replacements + 1
      if display == "full" then return output end
      return pandoc.BulletList(items)
    end,
  })
  return walked, replacements
end

local function prepare_shared_blocks(blocks, meta)
  local configured = meta["syllabus-page-break-before"]
  local targets = {}
  if configured ~= nil and FORMAT:match("latex") then
    local configured_type = ptype(configured)
    if configured_type == "Map" or configured_type == "Blocks" then
      fail("syllabus-page-break-before must be a shared-section id or a list of ids")
    end
    local declared = configured_type == "List" and configured or {configured}
    for index, value in ipairs(declared) do
      local identifier = normalize(meta_string(value):gsub("^#", ""))
      if identifier == "" then
        fail("syllabus-page-break-before item " .. index .. " must not be empty")
      end
      if targets[identifier] ~= nil then
        fail("duplicate syllabus-page-break-before target: #" .. identifier)
      end
      targets[identifier] = false
    end
  end

  local walked = blocks:walk({
    Div = function(div)
      if has_class(div.attr, "website-only") then return {} end
      if not has_class(div.attr, "course-share") then return nil end
      local identifier = normalize(div.identifier)
      if targets[identifier] == nil then return div.content end
      targets[identifier] = true
      local output = pandoc.Blocks({pandoc.RawBlock("latex", "\\clearpage")})
      output:extend(div.content)
      return output
    end,
  })
  for identifier, found in pairs(targets) do
    if not found then
      fail("syllabus-page-break-before shared section not found: #" .. identifier)
    end
  end
  return walked
end

local function normalize_teaching_assistants(value)
  local names = pandoc.MetaList({})
  if value == nil then return names end
  local is_list = ptype(value) == "List"
  if not is_list and meta_string(value) == "" then return names end
  local declared = is_list and value or {value}
  for index, item in ipairs(declared) do
    local item_type = ptype(item)
    if item_type == "List" or item_type == "Map" or item_type == "Blocks" then
      fail("course.teaching-assistants item " .. index .. " must be a name")
    end
    local blocks = markdown_blocks(item)
    if #blocks ~= 1 or (blocks[1].t ~= "Para" and blocks[1].t ~= "Plain") then
      fail("course.teaching-assistants item " .. index .. " must be a single-line name")
    end
    local name = clone_inlines(blocks[1].content)
    if meta_string(name) == "" then
      fail("course.teaching-assistants item " .. index .. " must not be empty")
    end
    names:insert(pandoc.MetaInlines(name))
  end
  return names
end

local function apply_course_template_metadata(meta, calendar_config)
  local course = meta.course
  if course == nil then return meta end
  local mappings = {
    {"affiliation", "school"},
    {"coursenumber", "number"},
    {"coursetitle", "title"},
    {"email", "email"},
    {"instructor", "instructor"},
    {"term", "term"},
    {"website", "website"},
    {"time", "meetings"},
    {"meetingsshort", "meetings-short"},
    {"classroom", "location"},
    {"address", "office"},
    {"officehours", "office-hours"},
  }
  for _, mapping in ipairs(mappings) do
    if meta[mapping[1]] == nil and course[mapping[2]] ~= nil then
      meta[mapping[1]] = course[mapping[2]]
    end
  end

  if meta.meetingsshort == nil
      and calendar_config ~= nil
      and calendar_config.short_summary ~= "" then
    meta.meetingsshort = pandoc.MetaString(calendar_config.short_summary)
  end

  local assistant_source = meta.teachingassistants
    or course["teaching-assistants"]
  local assistants = normalize_teaching_assistants(assistant_source)
  if #assistants > 0 then
    meta.teachingassistants = assistants
    if meta.teachingassistantslabel == nil then
      local label = #assistants == 1 and "Teaching assistant" or "Teaching assistants"
      meta.teachingassistantslabel = pandoc.MetaString(label)
    end
  elseif meta.teachingassistants ~= nil then
    meta.teachingassistants = nil
  end
  return meta
end

local function replace_required_materials(blocks, materials, meta)
  local replacements = 0
  local walked = blocks:walk({
    Div = function(div)
      if has_class(div.attr, "required-materials") then
        if #materials == 0 then
          fail("found {.required-materials} but no course-materials metadata")
        end
        replacements = replacements + 1
        return material_list(materials, meta)
      end
    end,
  })
  return walked, replacements
end

local function policy_list(meta)
  local declared = meta["course-policies"]
  if declared == nil then return nil end
  if ptype(declared) ~= "List" then
    fail("course-policies must be a YAML list")
  end
  local items = {}
  for index, policy in ipairs(declared) do
    local title = meta_string(policy.title)
    local summary = markdown_blocks(policy.syllabus or policy.summary)
    if title == "" or #summary == 0 then
      fail("course-policies item " .. index .. " needs title and syllabus or summary")
    end
    local first = summary[1]
    if first.t ~= "Plain" and first.t ~= "Para" then
      first = pandoc.Para({pandoc.Str(stringify(first))})
      summary[1] = first
    end
    local content = pandoc.Inlines({pandoc.Strong({pandoc.Str(title .. ".")})})
    if #first.content > 0 then content:insert(pandoc.Space()) end
    for _, inline in ipairs(first.content) do content:insert(inline:clone()) end
    first.content = content
    table.insert(items, summary)
  end
  return pandoc.BulletList(items)
end

local function replace_syllabus_policies(blocks, meta)
  local generated = policy_list(meta)
  if generated == nil then return blocks end
  return blocks:walk({
    Div = function(div)
      if has_class(div.attr, "syllabus-policies") then
        return generated
      end
    end,
  })
end

local function parse_field_item(item)
  if #item == 0 then
    return nil
  end
  local first = item[1]
  if first.t ~= "Plain" and first.t ~= "Para" then
    return nil
  end
  local inlines = clone_inlines(first.content)
  if #inlines == 0 or inlines[1].t ~= "Str" then
    return nil
  end
  local raw = inlines[1].text
  local label = raw:match("^([^:]+):$")
  if label == nil then
    return nil
  end
  inlines:remove(1)
  trim_leading_spaces(inlines)
  local value = pandoc.Blocks({})
  value:insert(first.t == "Para" and pandoc.Para(inlines) or pandoc.Plain(inlines))
  for index = 2, #item do
    value:insert(item[index]:clone())
  end
  return {
    label = label,
    normalized = normalize(label),
    blocks = value,
  }
end

local function parse_meeting(heading, blocks, materials_by_shorthand, generated_dates)
  local meeting = {
    date = generated_dates and nil or compact_date(heading.content),
    topic = pandoc.Blocks({}),
    fields = {},
    by_name = {},
  }
  for _, block in ipairs(blocks) do
    if block.t == "BulletList" then
      for _, item in ipairs(block.content) do
        local field = parse_field_item(item)
        if field == nil then
          fail("every schedule list item under " .. stringify(heading.content) .. " must begin with a plain label such as CB: or assignment:")
        end
        local material = materials_by_shorthand[field.label]
        if material == nil and not RESERVED_FIELDS[field.normalized] then
          fail("undeclared or unknown schedule label '" .. field.label .. "' under " .. stringify(heading.content))
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
      fail("meeting " .. stringify(heading.content) .. " has both a topic paragraph and a topic: field")
    end
    meeting.topic = clone_blocks(explicit_topic.blocks)
  end
  if #meeting.topic == 0 then
    fail("meeting " .. stringify(heading.content) .. " needs a topic paragraph")
  end
  return meeting
end

local function field_text(meeting, name)
  local fields = meeting.by_name[name]
  if fields == nil or fields[1] == nil then
    return ""
  end
  return normalize(stringify(fields[1].blocks))
end

local function attendance_label(meeting)
  local fields = meeting.by_name.attendance
  if fields == nil then return "" end
  if #fields ~= 1 then
    fail("attendance may appear only once under " .. stringify(meeting.topic))
  end
  local attendance = normalize(stringify(fields[1].blocks))
  if attendance == "optional" then return "Optional" end
  if attendance == "required" then return "Required" end
  fail("attendance must be optional or required under " .. stringify(meeting.topic))
end

local function validate_meeting(meeting)
  local entry_type = field_text(meeting, "type")
  local attendance = attendance_label(meeting)
  if entry_type ~= "ta-session" then return end
  if attendance ~= "Optional" then
    fail("ta-session entries require attendance: optional under " .. stringify(meeting.topic))
  end
  if field_text(meeting, "time") == "" then
    fail("ta-session entries require time under " .. stringify(meeting.topic))
  end
  if field_text(meeting, "room") == "" then
    fail("ta-session entries require room under " .. stringify(meeting.topic))
  end
end

local function meeting_counts(meeting)
  local entry_type = field_text(meeting, "type")
  local explicit = field_text(meeting, "counts-as-class")
  if explicit ~= "" then
    if explicit == "yes" or explicit == "true" or explicit == "1" then
      if entry_type == "ta-session" then
        fail("ta-session entries cannot count as class sessions under " .. stringify(meeting.topic))
      end
      return true
    elseif explicit == "no" or explicit == "false" or explicit == "0" then
      return false
    else
      fail("counts-as-class must be yes/no or true/false under " .. stringify(meeting.date))
    end
  end
  return not NONCOUNTING_TYPES[entry_type]
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
  local explicit = field_text(meeting, "on-deck")
  if explicit == "" or explicit == "yes" or explicit == "true" or explicit == "1" then
    return true
  end
  if explicit == "no" or explicit == "false" or explicit == "0" then return false end
  fail("on-deck must be yes/no or true/false under " .. stringify(meeting.date))
end

local function first_block_inlines(blocks)
  if blocks == nil or #blocks == 0 then
    return pandoc.Inlines({})
  end
  local first = blocks[1]
  if first.t == "Plain" or first.t == "Para" then
    return clone_inlines(first.content)
  end
  return pandoc.Inlines({pandoc.Str(stringify(blocks))})
end

local function labeled_blocks(label, blocks, italic_value)
  local result = clone_blocks(blocks)
  if #result == 0 then
    result:insert(pandoc.Plain({}))
  end
  local first = result[1]
  if first.t ~= "Plain" and first.t ~= "Para" then
    first = pandoc.Plain({pandoc.Str(stringify(result))})
    result = pandoc.Blocks({first})
  end
  local value = clone_inlines(first.content)
  local prefix = pandoc.Inlines({pandoc.Strong({pandoc.Str(label .. ":")})})
  if #value > 0 then
    prefix:insert(pandoc.Space())
    if italic_value then
      prefix:insert(pandoc.Emph(value))
    else
      for _, inline in ipairs(value) do
        prefix:insert(inline)
      end
    end
  end
  first.content = prefix
  return result
end

local function run_in_labeled_blocks(label, blocks, style, italic_value)
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
  local value = clone_inlines(first.content)
  local content = pandoc.Inlines({label_inline})
  if #value > 0 then
    content:insert(pandoc.Space())
    if italic_value then
      content:insert(pandoc.Emph(value))
    else
      for _, inline in ipairs(value) do content:insert(inline) end
    end
  end
  first.content = content
  return result
end

local function optional_reading_blocks(fields)
  if #fields == 1 then
    return run_in_labeled_blocks("Optional", fields[1].blocks, "italic", false)
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

local function assignment_blocks(fields)
  if #fields == 1 then
    return run_in_labeled_blocks(
      "Assignment",
      fields[1].blocks,
      "strong-italic",
      true
    )
  end
  local assignments = {}
  for _, field in ipairs(fields) do
    local blocks = clone_blocks(field.blocks)
    local first = blocks[1]
    if first and (first.t == "Plain" or first.t == "Para") then
      first.content = pandoc.Inlines({pandoc.Emph(clone_inlines(first.content))})
    end
    table.insert(assignments, blocks)
  end
  return pandoc.Blocks({
    pandoc.Plain({pandoc.Strong({
      pandoc.Emph({pandoc.Str("Assignments:")}),
    })}),
    pandoc.BulletList(assignments),
  })
end

local function meeting_date_blocks(meeting)
  local result = pandoc.Blocks({pandoc.Plain(clone_inlines(meeting.date))})
  if field_text(meeting, "type") == "ta-session" then return result end
  local details = pandoc.Inlines({})
  local function add_detail(name)
    local fields = meeting.by_name[name]
    if fields == nil then return end
    local value = first_block_inlines(fields[1].blocks)
    if #value == 0 then return end
    if #details > 0 then
      details:insert(pandoc.Str(" ·"))
      details:insert(pandoc.Space())
    end
    for _, inline in ipairs(value) do details:insert(inline) end
  end
  add_detail("time")
  add_detail("room")
  if #details > 0 then
    result:insert(pandoc.Plain({pandoc.Emph(details)}))
  end
  return result
end

local function meeting_topic_blocks(meeting, keep_with_next)
  local result = clone_blocks(meeting.topic)
  local entry_type = field_text(meeting, "type")
  if keep_with_next and FORMAT:match("latex") then
    local first = result[1]
    local marker = pandoc.RawInline("latex", "\\SyllabusKeepWithNextRow{}")
    if first and (first.t == "Plain" or first.t == "Para") then
      first.content:insert(1, marker)
    else
      result:insert(1, pandoc.Plain({marker}))
    end
  end
  if meeting.on_deck_group ~= nil then
    local on_deck = pandoc.Inlines({})
    if FORMAT:match("latex") then
      on_deck:insert(pandoc.RawInline("latex", "\\SyllabusOnDeck{"))
    end
    on_deck:insert(pandoc.Str("On"))
    on_deck:insert(pandoc.Space())
    on_deck:insert(pandoc.Str("deck:"))
    on_deck:insert(pandoc.Space())
    on_deck:insert(pandoc.Str("Panel"))
    on_deck:insert(pandoc.Space())
    on_deck:insert(pandoc.Str(tostring(meeting.on_deck_group)))
    if FORMAT:match("latex") then
      on_deck:insert(pandoc.RawInline("latex", "}"))
    end
    result:insert(pandoc.Plain(on_deck))
  end
  local attendance = attendance_label(meeting)
  if attendance ~= "" then
    local flag = pandoc.Inlines({})
    if FORMAT:match("latex") then
      flag:insert(pandoc.RawInline("latex", "\\SyllabusScheduleFlag{"))
    end
    flag:insert(pandoc.Str(attendance))
    if FORMAT:match("latex") then
      flag:insert(pandoc.RawInline("latex", "}"))
    end
    if entry_type == "ta-session" then
      local function add_detail(name)
        local fields = meeting.by_name[name]
        if fields == nil then return end
        local value = first_block_inlines(fields[1].blocks)
        if #value == 0 then return end
        flag:insert(pandoc.Str(" ·"))
        flag:insert(pandoc.Space())
        flag:insert(pandoc.Emph(value))
      end
      add_detail("time")
      add_detail("room")
    end
    result:insert(pandoc.Plain(flag))
  end
  local assignments_rendered = false
  for _, field in ipairs(meeting.fields) do
    if field.normalized == "assignment" then
      if not assignments_rendered then
        result:extend(assignment_blocks(meeting.by_name.assignment))
        assignments_rendered = true
      end
    elseif field.normalized == "activity" then
      result:extend(labeled_blocks("Activity", field.blocks, false))
    elseif field.normalized == "note" then
      local blocks = clone_blocks(field.blocks)
      local first = blocks[1]
      if first and (first.t == "Plain" or first.t == "Para") then
        first.content = pandoc.Inlines({pandoc.Emph(clone_inlines(first.content))})
      end
      result:extend(blocks)
    elseif field.normalized == "rescheduled-to" then
      result:extend(labeled_blocks("Rescheduled to", field.blocks, true))
    end
  end
  return result
end

local function meeting_reading_blocks(meeting)
  local result = pandoc.Blocks({})
  local optional_rendered = false
  for _, field in ipairs(meeting.fields) do
    if field.material ~= nil then
      result:extend(labeled_blocks(field.label, field.blocks, false))
    elseif field.normalized == "additional" then
      result:extend(clone_blocks(field.blocks))
    elseif field.normalized == "optional" then
      if not optional_rendered then
        result:extend(optional_reading_blocks(meeting.by_name.optional))
        optional_rendered = true
      end
    end
  end
  if #result == 0 then
    result:insert(pandoc.Plain({}))
  end
  return result
end

local function cell(blocks, alignment, colspan)
  return pandoc.Cell(blocks, alignment or pandoc.AlignDefault, 1, colspan or 1)
end

local function unit_inlines(inlines)
  if FORMAT:match("latex") then
    local result = pandoc.Inlines({pandoc.RawInline("latex", "\\SyllabusUnit{")})
    for _, inline in ipairs(inlines) do result:insert(inline:clone()) end
    result:insert(pandoc.RawInline("latex", "}"))
    return result
  end
  return pandoc.Inlines({pandoc.Span(clone_inlines(inlines), pandoc.Attr("", {"syllabus-unit"}))})
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

local function header_cell(text, alignment, pad_after)
  local inlines = pandoc.Inlines({})
  if FORMAT:match("latex") then
    inlines:insert(pandoc.RawInline("latex", "\\sffamily{}"))
  end
  inlines:insert(pandoc.Str(text))
  if pad_after and FORMAT:match("latex") then
    inlines:insert(pandoc.RawInline("latex", "\\hspace{0.55em}"))
  end
  return cell({pandoc.Plain({pandoc.Strong(inlines)})}, alignment)
end

local function class_number_blocks(number)
  local inlines = pandoc.Inlines({})
  if number ~= "" then
    if FORMAT:match("latex") then
      inlines:insert(pandoc.RawInline("latex", "\\sffamily{}"))
    end
    inlines:insert(pandoc.Str(number))
    if FORMAT:match("latex") then
      inlines:insert(pandoc.RawInline("latex", "\\hspace{0.55em}"))
    end
  end
  return {pandoc.Plain(inlines)}
end

local function schedule_table(rows)
  local head = pandoc.TableHead({
    pandoc.Row({
      header_cell("#", pandoc.AlignRight, true),
      header_cell("Date", pandoc.AlignLeft),
      header_cell("Class", pandoc.AlignLeft),
      header_cell("Readings", pandoc.AlignLeft),
    })
  })
  -- Pandoc 3.8 (bundled with Quarto 1.9) exposes table bodies as records but
  -- does not yet expose a pandoc.TableBody constructor.
  local body = {
    attr = pandoc.Attr(),
    body = rows,
    head = {},
    row_head_columns = 0,
  }
  return pandoc.Table(
    pandoc.Caption(),
    {
      {pandoc.AlignRight, 0.05},
      {pandoc.AlignLeft, 0.16},
      {pandoc.AlignLeft, 0.49},
      {pandoc.AlignLeft, 0.30},
    },
    head,
    {body},
    pandoc.TableFoot({}),
    pandoc.Attr("", {"syllabus-schedule"})
  )
end

local function read_schedule_source(meta)
  local path = meta_string(meta["course-schedule"])
  if path == "" then
    fail("an empty {.course-schedule} placeholder requires course-schedule metadata")
  end
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
  for _, candidate in ipairs(candidates) do
    handle, message = io.open(candidate, "r")
    if handle ~= nil then break end
  end
  if handle == nil then
    fail("cannot read course schedule " .. path .. ": " .. (message or "unknown error"))
  end
  local source = handle:read("*a")
  handle:close()
  return pandoc.read(source, "markdown+fenced_divs+header_attributes").blocks
end

local function resolve_schedule_region(blocks, meta)
  local meaningful = pandoc.Blocks({})
  for _, block in ipairs(blocks) do
    local quarto_artifact = block.t == "Div"
      and has_class(block.attr, "hidden")
      and #block.content == 0
    if not quarto_artifact then meaningful:insert(block) end
  end

  local placeholder_index = nil
  for index, block in ipairs(meaningful) do
    if block.t == "Div" and has_class(block.attr, "course-schedule") then
      if placeholder_index ~= nil then
        fail("Schedule contains more than one {.course-schedule} placeholder")
      end
      placeholder_index = index
    end
  end

  if placeholder_index ~= nil then
    local preface = pandoc.Blocks({})
    for index = 1, placeholder_index - 1 do
      preface:insert(meaningful[index]:clone())
    end
    if placeholder_index < #meaningful then
      fail("Schedule prose must appear before the {.course-schedule} placeholder")
    end
    local placeholder = meaningful[placeholder_index]
    local schedule = #placeholder.content > 0
      and clone_blocks(placeholder.content)
      or read_schedule_source(meta)
    return preface, schedule
  end
  return pandoc.Blocks({}), meaningful
end

local function parse_schedule_region(blocks, materials_by_shorthand, calendar_config, course)
  local row_specs = {}
  local class_number = 0
  local on_deck_index = 0
  local on_deck_groups = on_deck_group_count(course)
  local unit_number = 0
  local date_allocator = calendar.new_allocator(calendar_config, fail)
  local index = 1
  while index <= #blocks do
    local block = blocks[index]
    if block.t == "Header" and block.level == 3 then
      local numbered = not has_class(block.attr, "unnumbered")
      if numbered then unit_number = unit_number + 1 end
      row_specs[#row_specs + 1] = {kind = "unit", row = pandoc.Row({
        cell({pandoc.Plain({})}, pandoc.AlignLeft),
        cell({pandoc.Plain({})}, pandoc.AlignLeft),
        cell({pandoc.Plain(unit_inlines(
          unit_title(block.content, numbered and unit_number or nil)
        ))}, pandoc.AlignLeft),
        cell({pandoc.Plain({})}, pandoc.AlignLeft),
      }, pandoc.Attr("", {"syllabus-unit-row"}))}
      index = index + 1
    elseif block.t == "Header" and block.level == 4 then
      local meeting_blocks = pandoc.Blocks({})
      local cursor = index + 1
      while cursor <= #blocks do
        local candidate = blocks[cursor]
        if candidate.t == "Header" and candidate.level <= 4 then
          break
        end
        meeting_blocks:insert(candidate)
        cursor = cursor + 1
      end
      local meeting = parse_meeting(
        block,
        meeting_blocks,
        materials_by_shorthand,
        date_allocator ~= nil
      )
      validate_meeting(meeting)
      local date_key = nil
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
        meeting.date = calendar.compact_inlines(assigned)
        date_key = assigned.iso
      else
        date_key = normalize(stringify(meeting.date))
      end
      local number = ""
      if meeting_counts(meeting) then
        class_number = class_number + 1
        number = tostring(class_number)
      end
      if on_deck_groups > 0 and meeting_is_on_deck(meeting) then
        on_deck_index = on_deck_index + 1
        meeting.on_deck_group = ((on_deck_index - 1) % on_deck_groups) + 1
      end
      local row_type = field_text(meeting, "type")
      local classes = {"syllabus-meeting-row"}
      if row_type ~= "" then table.insert(classes, "syllabus-" .. row_type) end
      row_specs[#row_specs + 1] = {
        kind = "meeting",
        meeting = meeting,
        date_key = date_key,
        number = number,
        classes = classes,
      }
      index = cursor
    else
      fail("Schedule content must begin with a level-three unit heading or level-four meeting; found " .. block.t)
    end
  end
  if #row_specs == 0 then
    fail("Schedule contains no entries")
  end
  if date_allocator ~= nil then date_allocator:finish() end

  -- Apply the nonbreaking row terminator to the earlier entry in each
  -- same-date run. Unit rows are skipped for comparison because they already
  -- keep with their following row through \SyllabusUnit.
  local next_meeting = nil
  for row_index = #row_specs, 1, -1 do
    local spec = row_specs[row_index]
    if spec.kind == "meeting" then
      spec.keep_with_next = spec.date_key ~= nil
        and spec.date_key ~= ""
        and next_meeting ~= nil
        and spec.date_key == next_meeting.date_key
      next_meeting = spec
    end
  end

  local rows = {}
  for _, spec in ipairs(row_specs) do
    if spec.kind == "unit" then
      rows[#rows + 1] = spec.row
    else
      local meeting = spec.meeting
      rows[#rows + 1] = pandoc.Row({
        cell(class_number_blocks(spec.number), pandoc.AlignRight),
        cell(meeting_date_blocks(meeting), pandoc.AlignLeft),
        cell(
          meeting_topic_blocks(meeting, spec.keep_with_next),
          pandoc.AlignLeft
        ),
        cell(meeting_reading_blocks(meeting), pandoc.AlignLeft),
      }, pandoc.Attr("", spec.classes))
    end
  end
  return schedule_table(rows)
end

local function replace_schedule(blocks, materials_by_shorthand, schedule_new_page, meta, calendar_config)
  local output = pandoc.Blocks({})
  local replaced = 0
  local index = 1
  while index <= #blocks do
    local block = blocks[index]
    local heading = block.t == "Header" and normalize(stringify(block.content)) or ""
    local is_schedule = block.t == "Header"
      and block.level <= 2
      and (heading == "schedule" or heading == "weekly-breakdown")
    if not is_schedule then
      output:insert(block)
      index = index + 1
    else
      if schedule_new_page and FORMAT:match("latex") then
        output:insert(pandoc.RawBlock("latex", "\\clearpage"))
      elseif FORMAT:match("latex") then
        output:insert(pandoc.RawBlock("latex", "\\Needspace{10\\baselineskip}"))
      end
      output:insert(block)
      local region = pandoc.Blocks({})
      local cursor = index + 1
      while cursor <= #blocks do
        local candidate = blocks[cursor]
        if candidate.t == "Header" and candidate.level <= block.level then
          break
        end
        local following = blocks[cursor + 1]
        local page_break_before_following_heading = candidate.t == "RawBlock"
          and candidate.format == "latex"
          and candidate.text:match("\\clearpage") ~= nil
          and following ~= nil
          and following.t == "Header"
          and following.level <= block.level
        if page_break_before_following_heading then break end
        region:insert(candidate)
        cursor = cursor + 1
      end
      local preface
      preface, region = resolve_schedule_region(region, meta)
      output:extend(preface)
      output:insert(parse_schedule_region(
        region,
        materials_by_shorthand,
        calendar_config,
        meta.course
      ))
      replaced = replaced + 1
      index = cursor
    end
  end
  return output, replaced
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

local function merge_source_document(doc, source_doc)
  if source_doc == nil then return doc end
  local merged = {}
  for key, value in pairs(source_doc.meta) do merged[key] = value end
  for key, value in pairs(doc.meta) do merged[key] = value end
  for _, key in ipairs({
    "bibliography",
    "course",
    "course-base-url",
    "course-schedule",
    "csl",
    "schedule-new-page",
    "suppress-bibliography",
    "updated",
  }) do
    if source_doc.meta[key] ~= nil then merged[key] = source_doc.meta[key] end
  end
  doc.meta = pandoc.Meta(merged)
  doc.blocks = clone_blocks(source_doc.blocks)
  return doc
end

function Pandoc(doc)
  doc = merge_source_document(doc, load_course_source(doc.meta))
  local calendar_config = calendar.configure(doc.meta.course, fail)
  doc.meta = apply_course_template_metadata(doc.meta, calendar_config)
  local schedule_new_page_value = doc.meta["syllabus-schedule-new-page"]
  if schedule_new_page_value == nil then
    schedule_new_page_value = doc.meta["schedule-new-page"]
  end
  local schedule_new_page = meta_boolean(schedule_new_page_value, true)
  local policy_display = normalize(meta_string(doc.meta["syllabus-policy-display"]))
  if policy_display == "" then policy_display = "summary" end
  if policy_display ~= "summary" and policy_display ~= "full" then
    fail("syllabus-policy-display must be summary or full")
  end
  local blocks = strip_source_positions(doc.blocks)
  blocks = prepare_shared_blocks(blocks, doc.meta)
  local semantic_replacements
  local materials
  local materials_by_shorthand
  blocks, materials, materials_by_shorthand, semantic_replacements =
    replace_course_material_sources(blocks, doc.meta)

  local material_replacements = semantic_replacements
  if #materials == 0 then
    materials, materials_by_shorthand = parse_materials(doc.meta)
    blocks, material_replacements = replace_required_materials(blocks, materials, doc.meta)
  end

  local policy_replacements
  blocks, policy_replacements = replace_course_policy_sources(blocks, policy_display)
  if policy_replacements == 0 then
    blocks = replace_syllabus_policies(blocks, doc.meta)
  end
  local schedule_replacements
  blocks, schedule_replacements = replace_schedule(
    blocks,
    materials_by_shorthand,
    schedule_new_page,
    doc.meta,
    calendar_config
  )
  if #materials > 0 and material_replacements == 0 then
    fail("course materials are declared but no materials source or placeholder was found")
  end
  doc.blocks = blocks
  return doc
end
