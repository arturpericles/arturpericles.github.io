local script_dir = (PANDOC_SCRIPT_FILE or ""):match("^(.*)[/\\][^/\\]+$") or "."
local calendar = dofile(script_dir .. "/../calendar.lua")

local function fail(message)
  error(message, 0)
end

local function test_config()
  return calendar.configure({
    ["start-date"] = pandoc.MetaString("2026-10-12"),
    ["end-date"] = pandoc.MetaString("2026-10-19"),
    ["meeting-days"] = pandoc.MetaList({
      pandoc.MetaString("mon"),
      pandoc.MetaString("wed"),
      pandoc.MetaString("fri"),
    }),
    ["meeting-time"] = pandoc.MetaString("1:15–2:30 p.m."),
  }, fail)
end

local function fixed_options()
  return {
    fixed_regular_date = true,
    entry_type = "no-class",
  }
end

local function expect_error(label, expected, action)
  local ok, message = pcall(action)
  if ok then
    error(label .. ": expected an error", 0)
  end
  if not tostring(message):find(expected, 1, true) then
    error(label .. ": expected error containing '" .. expected
      .. "'; found '" .. tostring(message) .. "'", 0)
  end
end

function Pandoc(doc)
  assert(calendar.is_fixed_closure_type("no-class"))
  assert(calendar.is_fixed_closure_type("holiday"))
  assert(calendar.is_fixed_closure_type("canceled"))
  assert(calendar.is_fixed_closure_type("cancelled"))
  assert(not calendar.is_fixed_closure_type("schedule-note"))

  local summaries = test_config()
  assert(summaries.summary == "Monday, Wednesday, and Friday, 1:15–2:30 p.m")
  assert(summaries.short_summary == "M, W, F, 1:15–2:30 p.m.")

  expect_error("missing fixed date", "requires an explicit date", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'Wellness Break'", fixed_options())
  end)

  expect_error("off-pattern closure", "is not a regular meeting date", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'Monday class'")
    allocator:assign(nil, "meeting 'Wednesday class'")
    allocator:assign("2026-10-15", "meeting 'Wellness Break'", fixed_options())
  end)

  expect_error("closure moved across a session", "skips generated date 2026-10-14", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'Monday class'")
    allocator:assign("2026-10-16", "meeting 'Wellness Break'", fixed_options())
  end)

  local allocator = calendar.new_allocator(test_config(), fail)
  allocator:assign(nil, "meeting 'Monday class'")
  allocator:assign(nil, "meeting 'Wednesday class'")
  local special = allocator:assign("2026-10-15", "meeting 'Special meeting'")
  assert(special.iso == "2026-10-15")
  local closure = allocator:assign(
    "2026-10-16",
    "meeting 'Wellness Break'",
    fixed_options()
  )
  assert(closure.iso == "2026-10-16")
  allocator:assign(nil, "meeting 'Following Monday class'")
  allocator:finish()

  return doc
end
