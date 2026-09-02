local script_dir = (PANDOC_SCRIPT_FILE or ""):match("^(.*)[/\\][^/\\]+$") or "."
local calendar = dofile(script_dir .. "/../calendar.lua")

local function fail(message)
  error(message, 0)
end

local function test_config()
  return calendar.configure({
    ["start-date"] = pandoc.MetaString("2026-08-31"),
    ["end-date"] = pandoc.MetaString("2026-09-02"),
    ["meeting-days"] = pandoc.MetaList({
      pandoc.MetaString("mon"),
      pandoc.MetaString("wed"),
    }),
  }, fail)
end

local function ta_options()
  return {entry_type = "ta-session"}
end

local function expect_error(label, expected, action)
  local ok, message = pcall(action)
  if ok then error(label .. ": expected an error", 0) end
  if not tostring(message):find(expected, 1, true) then
    error(label .. ": expected error containing '" .. expected
      .. "'; found '" .. tostring(message) .. "'", 0)
  end
end

function Pandoc(doc)
  assert(calendar.is_parallel_event_type("ta-session"))
  assert(calendar.is_parallel_event_type("TA session"))
  assert(not calendar.is_parallel_event_type("no-class"))

  -- A same-date TA before the primary does not consume the regular slot:
  -- the following undated primary still receives Aug. 31.
  local before_primary = calendar.new_allocator(test_config(), fail)
  local ta_before = before_primary:assign(
    "2026-08-31",
    "meeting 'TA session #1'",
    ta_options()
  )
  assert(ta_before.iso == "2026-08-31")
  local first_class = before_primary:assign(nil, "meeting 'Monday class'")
  assert(first_class.iso == "2026-08-31")
  local second_class = before_primary:assign(nil, "meeting 'Wednesday class'")
  assert(second_class.iso == "2026-09-02")
  before_primary:finish()

  -- A same-date TA after the primary is also valid and does not disturb the
  -- next generated slot.
  local after_primary = calendar.new_allocator(test_config(), fail)
  local monday = after_primary:assign(nil, "meeting 'Monday class'")
  assert(monday.iso == "2026-08-31")
  local ta_after = after_primary:assign(
    "2026-08-31",
    "meeting 'TA session #1'",
    ta_options()
  )
  assert(ta_after.iso == "2026-08-31")
  local wednesday = after_primary:assign(nil, "meeting 'Wednesday class'")
  assert(wednesday.iso == "2026-09-02")
  after_primary:finish()

  -- A TA may be a standalone event on an off-pattern date between regular
  -- meetings. It does not consume either generated slot.
  local standalone_off_pattern = calendar.new_allocator(test_config(), fail)
  local regular_monday = standalone_off_pattern:assign(
    nil,
    "meeting 'Monday class'"
  )
  assert(regular_monday.iso == "2026-08-31")
  local standalone_tuesday = standalone_off_pattern:assign(
    "2026-09-01",
    "meeting 'Standalone TA session'",
    ta_options()
  )
  assert(standalone_tuesday.iso == "2026-09-01")
  local regular_wednesday = standalone_off_pattern:assign(
    nil,
    "meeting 'Wednesday class'"
  )
  assert(regular_wednesday.iso == "2026-09-02")
  standalone_off_pattern:finish()

  -- A standalone TA may also fall after the configured calendar bounds once
  -- all regular slots have been covered.
  local standalone_after_end = calendar.new_allocator(test_config(), fail)
  standalone_after_end:assign(nil, "meeting 'Monday class'")
  standalone_after_end:assign(nil, "meeting 'Wednesday class'")
  local thursday_ta = standalone_after_end:assign(
    "2026-09-03",
    "meeting 'Post-calendar TA session'",
    ta_options()
  )
  assert(thursday_ta.iso == "2026-09-03")
  standalone_after_end:finish()

  expect_error("missing TA date", "requires an explicit date", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'TA session #1'", ta_options())
  end)

  expect_error("duplicate TA role", "duplicate ta-session schedule date", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign("2026-08-31", "meeting 'TA session #1'", ta_options())
    allocator:assign("2026-08-31", "meeting 'TA session #2'", ta_options())
  end)

  expect_error("duplicate primary role", "duplicate or out of order", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'Monday class'")
    allocator:assign("2026-08-31", "meeting 'Duplicate Monday class'")
  end)

  expect_error("TA skips a class date", "skips generated date 2026-08-31", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign("2026-09-02", "meeting 'TA session #1'", ta_options())
  end)

  expect_error("out-of-order TA date", "earlier than the preceding entry", function()
    local allocator = calendar.new_allocator(test_config(), fail)
    allocator:assign(nil, "meeting 'Monday class'")
    allocator:assign(nil, "meeting 'Wednesday class'")
    allocator:assign("2026-08-31", "meeting 'TA session #1'", ta_options())
  end)

  -- A TA on a regular date remains parallel: it neither consumes nor satisfies
  -- that date's required primary coverage.
  expect_error(
    "TA does not consume or satisfy regular coverage",
    "next unassigned date is 2026-08-31",
    function()
      local allocator = calendar.new_allocator(test_config(), fail)
      allocator:assign("2026-08-31", "meeting 'TA session #1'", ta_options())
      allocator:finish()
    end
  )

  return doc
end
