-- Shared civil-calendar utilities for the HTML and PDF course filters.

local calendar = {}
local stringify = pandoc.utils.stringify

local WEEKDAYS = {
  [1] = {name = "Monday", short = "M"},
  [2] = {name = "Tuesday", short = "Tu"},
  [3] = {name = "Wednesday", short = "W"},
  [4] = {name = "Thursday", short = "Th"},
  [5] = {name = "Friday", short = "F"},
  [6] = {name = "Saturday", short = "Sa"},
  [7] = {name = "Sunday", short = "Su"},
}

local WEEKDAY_ALIASES = {
  mon = 1, monday = 1,
  tue = 2, tues = 2, tuesday = 2,
  wed = 3, weds = 3, wednesday = 3,
  thu = 4, thur = 4, thurs = 4, thursday = 4,
  fri = 5, friday = 5,
  sat = 6, saturday = 6,
  sun = 7, sunday = 7,
}

local MONTH_ABBREVIATIONS = {
  "Jan.", "Feb.", "Mar.", "Apr.", "May", "June",
  "July", "Aug.", "Sept.", "Oct.", "Nov.", "Dec.",
}

local FIXED_CLOSURE_TYPES = {
  ["cancelled"] = true,
  ["canceled"] = true,
  ["holiday"] = true,
  ["no-class"] = true,
}

local PARALLEL_EVENT_TYPES = {
  ["ta-session"] = true,
}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function text(value)
  if value == nil then return "" end
  return trim(stringify(value))
end

local function normalized_token(value)
  return text(value):lower():gsub("[%s_]+", "-"):gsub("%-+", "-")
end

function calendar.is_fixed_closure_type(value)
  return FIXED_CLOSURE_TYPES[normalized_token(value)] == true
end

function calendar.is_parallel_event_type(value)
  return PARALLEL_EVENT_TYPES[normalized_token(value)] == true
end

local function is_leap_year(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function days_in_month(year, month)
  local lengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if month == 2 and is_leap_year(year) then return 29 end
  return lengths[month]
end

local function days_from_civil(year, month, day)
  year = year - (month <= 2 and 1 or 0)
  local era = math.floor(year / 400)
  local year_of_era = year - era * 400
  local adjusted_month = month + (month > 2 and -3 or 9)
  local day_of_year = math.floor((153 * adjusted_month + 2) / 5) + day - 1
  local day_of_era = year_of_era * 365
    + math.floor(year_of_era / 4)
    - math.floor(year_of_era / 100)
    + day_of_year
  return era * 146097 + day_of_era - 719468
end

local function iso_date(date)
  return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function parse_date(value, label, fail)
  local raw = text(value)
  local year, month, day = raw:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if year == nil or month == nil or day == nil
      or month < 1 or month > 12
      or day < 1 or day > days_in_month(year, month) then
    fail(label .. " must be an ISO date in YYYY-MM-DD form; found " .. raw)
  end
  local date = {year = year, month = month, day = day}
  date.ordinal = days_from_civil(year, month, day)
  date.weekday = ((date.ordinal + 3) % 7) + 1
  date.iso = iso_date(date)
  return date
end

local function next_date(date)
  local year, month, day = date.year, date.month, date.day + 1
  if day > days_in_month(year, month) then
    day = 1
    month = month + 1
    if month > 12 then
      month = 1
      year = year + 1
    end
  end
  local result = {year = year, month = month, day = day}
  result.ordinal = date.ordinal + 1
  result.weekday = (date.weekday % 7) + 1
  result.iso = iso_date(result)
  return result
end

local function natural_join(values)
  if #values == 0 then return "" end
  if #values == 1 then return values[1] end
  if #values == 2 then return values[1] .. " and " .. values[2] end
  return table.concat(values, ", ", 1, #values - 1) .. ", and " .. values[#values]
end

function calendar.configure(course, fail)
  if course == nil then return nil end
  local start_value = course["start-date"]
  local end_value = course["end-date"]
  local days_value = course["meeting-days"]
  local has_calendar = start_value ~= nil or end_value ~= nil or days_value ~= nil
  if not has_calendar then return nil end
  if start_value == nil or end_value == nil or days_value == nil then
    fail("course start-date, end-date, and meeting-days must be provided together")
  end
  if pandoc.utils.type(days_value) ~= "List" then
    fail("course meeting-days must be a YAML list such as [mon, wed, fri]")
  end

  local start_date = parse_date(start_value, "course start-date", fail)
  local end_date = parse_date(end_value, "course end-date", fail)
  if start_date.ordinal > end_date.ordinal then
    fail("course start-date must not be later than end-date")
  end

  local enabled = {}
  local ordered_days = {}
  for _, value in ipairs(days_value) do
    local token = text(value):lower():gsub("%.$", "")
    local weekday = WEEKDAY_ALIASES[token]
    if weekday == nil then
      fail("unknown course meeting day '" .. text(value) .. "'")
    end
    if enabled[weekday] then
      fail("duplicate course meeting day '" .. WEEKDAYS[weekday].name .. "'")
    end
    enabled[weekday] = true
    table.insert(ordered_days, weekday)
  end
  if #ordered_days == 0 then fail("course meeting-days must not be empty") end
  table.sort(ordered_days)

  local slots = {}
  local slot_positions = {}
  local cursor = start_date
  while cursor.ordinal <= end_date.ordinal do
    if enabled[cursor.weekday] then
      local slot = {
        year = cursor.year,
        month = cursor.month,
        day = cursor.day,
        ordinal = cursor.ordinal,
        weekday = cursor.weekday,
        iso = cursor.iso,
      }
      table.insert(slots, slot)
      slot_positions[slot.iso] = #slots
    end
    cursor = next_date(cursor)
  end
  if #slots == 0 then
    fail("course calendar contains no dates matching meeting-days")
  end

  local day_names = {}
  local short_day_names = {}
  for _, weekday in ipairs(ordered_days) do
    table.insert(day_names, WEEKDAYS[weekday].name)
    table.insert(short_day_names, WEEKDAYS[weekday].short)
  end
  local summary = natural_join(day_names)
  local short_summary = table.concat(short_day_names, ", ")
  -- Keep the website fact unpunctuated, while preserving the authored time's
  -- terminal punctuation in the compact summary used by the PDF title block.
  local authored_meeting_time = text(course["meeting-time"])
  local meeting_time = authored_meeting_time:gsub("%.$", "")
  if meeting_time ~= "" then
    summary = summary .. ", " .. meeting_time
    short_summary = short_summary .. ", " .. authored_meeting_time
  end
  course.meetings = summary

  return {
    start_date = start_date,
    end_date = end_date,
    enabled_weekdays = enabled,
    slots = slots,
    slot_positions = slot_positions,
    summary = summary,
    short_summary = short_summary,
  }
end

function calendar.new_allocator(config, fail)
  if config == nil then return nil end
  local next_slot = 1
  local used_by_date_and_role = {}
  local last_date = nil

  local allocator = {}

  function allocator:assign(override_value, label, options)
    options = options or {}
    local fixed_regular_date = options.fixed_regular_date == true
    local entry_type = trim(options.entry_type or "closure")
    local parallel_event = calendar.is_parallel_event_type(entry_type)
    local date_role = parallel_event and normalized_token(entry_type) or "primary"
    local override = text(override_value)
    if fixed_regular_date and override == "" then
      fail(label .. " is a fixed " .. entry_type
        .. " entry and requires an explicit date in YYYY-MM-DD form")
    end
    if parallel_event and override == "" then
      fail(label .. " is a parallel " .. entry_type
        .. " entry and requires an explicit date in YYYY-MM-DD form")
    end
    local date
    if override == "" then
      date = config.slots[next_slot]
      if date == nil then
        fail("schedule has more entries than generated dates; extra entry is " .. label)
      end
      next_slot = next_slot + 1
    else
      date = parse_date(override, "date override under " .. label, fail)
      local position = config.slot_positions[date.iso]
      if fixed_regular_date and position == nil then
        fail("date " .. date.iso .. " under " .. label
          .. " is not a regular meeting date; fixed " .. entry_type
          .. " entries must use a generated course date")
      end
      if parallel_event and position ~= nil then
        if position > next_slot then
          fail("parallel date override " .. date.iso .. " under " .. label
            .. " skips generated date " .. config.slots[next_slot].iso
            .. "; add the intervening meeting or no-class entry first")
        end
      elseif position ~= nil then
        if position < next_slot then
          fail("date override " .. date.iso .. " under " .. label .. " is duplicate or out of order")
        elseif position > next_slot then
          fail("date override " .. date.iso .. " under " .. label
            .. " skips generated date " .. config.slots[next_slot].iso
            .. "; add an intervening meeting or no-class entry")
        end
        next_slot = next_slot + 1
      end
    end
    if last_date ~= nil and date.ordinal < last_date.ordinal then
      fail("schedule date " .. date.iso .. " under " .. label
        .. " is earlier than the preceding entry on " .. last_date.iso)
    end
    local used_roles = used_by_date_and_role[date.iso] or {}
    if used_roles[date_role] ~= nil then
      fail("duplicate " .. date_role .. " schedule date " .. date.iso .. " under " .. label
        .. "; already used by " .. used_roles[date_role])
    end
    used_roles[date_role] = label
    used_by_date_and_role[date.iso] = used_roles
    last_date = date
    return date
  end

  function allocator:finish()
    if next_slot <= #config.slots then
      fail("schedule has fewer entries than generated dates; next unassigned date is "
        .. config.slots[next_slot].iso)
    end
  end

  return allocator
end

function calendar.website_inlines(date)
  return pandoc.Inlines({
    pandoc.Str(WEEKDAYS[date.weekday].name .. ","),
    pandoc.Space(),
    pandoc.Str(MONTH_ABBREVIATIONS[date.month]),
    pandoc.Space(),
    pandoc.Str(tostring(date.day)),
  })
end

function calendar.compact_inlines(date)
  return pandoc.Inlines({
    pandoc.Str(MONTH_ABBREVIATIONS[date.month]),
    pandoc.Space(),
    pandoc.Str(tostring(date.day)),
    pandoc.Space(),
    pandoc.Str("(" .. WEEKDAYS[date.weekday].short .. ")"),
  })
end

return calendar
