local stringify = pandoc.utils.stringify

local generated_expectations = {
  ["TA before class"] = true,
  ["Monday class"] = false,
  ["Standalone TA session"] = false,
  ["Wednesday class"] = false,
  ["Friday class"] = true,
  ["TA after class"] = false,
  ["Labor Day"] = true,
  ["TA on closure"] = false,
}

local manual_expectations = {
  ["Blockquote primary topic"] = true,
  ["TA after blockquote class"] = false,
  ["Standalone manual TA"] = false,
  ["Later manual class"] = false,
}

local function row_text(row)
  local values = {}
  for _, cell in ipairs(row.cells) do
    table.insert(values, stringify(cell.contents))
  end
  return table.concat(values, " ")
end

local function row_keep_count(row)
  local count = 0
  for _, cell in ipairs(row.cells) do
    pandoc.Div(cell.contents):walk({
      RawInline = function(raw)
        if raw.format == "latex"
            and raw.text == "\\SyllabusKeepWithNextRow{}" then
          count = count + 1
        end
      end,
    })
  end
  return count
end

function Pandoc(doc)
  local rows = {}
  local schedule_tables = 0

  doc:walk({
    Table = function(table_block)
      schedule_tables = schedule_tables + 1
      for _, body in ipairs(table_block.bodies) do
        for _, row in ipairs(body.body) do
          table.insert(rows, {row = row, text = row_text(row)})
        end
      end
    end,
  })

  assert(schedule_tables == 1, "expected one rendered schedule table")
  local expectations = nil
  for _, record in ipairs(rows) do
    if record.text:find("TA before class", 1, true) then
      expectations = generated_expectations
    elseif record.text:find("Blockquote primary topic", 1, true) then
      expectations = manual_expectations
    end
  end
  assert(expectations ~= nil, "unrecognized parallel-event fixture")

  local seen = {}
  for _, record in ipairs(rows) do
    for label, expected_keep in pairs(expectations) do
      if record.text:find(label, 1, true) then
        local count = row_keep_count(record.row)
        local expected_count = expected_keep and 1 or 0
        assert(
          count == expected_count,
          label .. ": expected " .. expected_count
            .. " keep marker(s), found " .. count
        )
        seen[label] = true
      end
    end
  end
  for label, _ in pairs(expectations) do
    assert(seen[label], "missing rendered schedule row: " .. label)
  end
  return doc
end
