local Files = require('orgmode.parser.files')
local Table = require('orgmode.parser.table')
local Duration = require('orgmode.objects.duration')

---@class ClockReport
---@field total_duration Duration
---@field total_income number
---@field total_emotion number
---@field total_invest number
---@field total_roi number
---@field from Date
---@field to Date
---@field table Table
---@field files table[]
local ClockReport = {}

function ClockReport:new(opts)
  opts = opts or {}
  local data = {}
  data.from = opts.from
  data.to = opts.to
  data.total_duration = opts.total_duration
  data.total_income = opts.total_income
  data.total_emotion = opts.total_emotion
  data.total_invest = opts.total_invest
  data.total_roi = opts.total_roi
  data.files = opts.files or {}
  data.table = opts.table
  setmetatable(data, self)
  self.__index = self
  return data
end

local function local_get_property(headline, name)
  local item = headline:get_property(name)
  if item == nil then
    item = '1'
  end
  return tonumber(item)
end

---@param start_line number
---@return table[]
function ClockReport:draw_for_agenda(start_line)
  local data = {
    { 'File', 'Headline', 'Time', 'Emotion', 'Invest', 'Income', 'Roi' },
    'hr',
    {
      '',
      'ALL Total time',
      self.total_duration:to_string(),
      tostring(self.total_emotion),
      tostring(self.total_invest),
      tostring(self.total_income),
      string.format('%.1f', self.total_roi),
    },
    'hr',
  }

  for _, file in ipairs(self.files) do
    table.insert(data, {
      { value = file.name, reference = file },
      'File time',
      file.total_duration:to_string(),
      tostring(file.total_emotion),
      tostring(file.total_invest),
      tostring(file.total_income),
      string.format('%.1f', file.total_roi),
    })
    for _, headline in ipairs(file.headlines) do
      local income = headline:get_income()
      local emotion = local_get_property(headline, 'emotion')
      local invest = headline:calc_invest(self.from, self.to)
      table.insert(data, {
        '',
        { value = '[' .. headline.todo_keyword.value .. '] ' .. headline.title, reference = headline },
        headline.logbook:get_total(self.from, self.to):to_string(),
        tostring(emotion),
        tostring(invest),
        tostring(income),
        string.format('%.1f', headline:calc_roi(invest, income)),
      })
    end
    table.insert(data, 'hr')
  end

  local clock_table = Table.from_list(data, start_line):compile()
  self.table = clock_table
  local result = {}
  for i, row in ipairs(clock_table.rows) do
    local highlights = {}
    local prev_row = clock_table.rows[i - 1]
    if prev_row and prev_row.is_separator then
      for _, cell in ipairs(row.cells) do
        local range = cell.range:clone()
        range.end_col = range.end_col + 1
        table.insert(highlights, {
          hlgroup = 'OrgBold',
          range = range,
        })
      end
    elseif i > 1 and not row.is_separator then
      for _, cell in ipairs(row.cells) do
        if cell.reference then
          local range = cell.range:clone()
          range.end_col = range.end_col + 1
          table.insert(highlights, {
            hlgroup = 'OrgUnderline',
            range = range,
          })
        end
      end
    end

    table.insert(result, {
      line_content = row.content,
      is_table = true,
      table_row = row,
      highlights = highlights,
    })
  end
  return result
end

---@param item table
function ClockReport:find_agenda_item(item)
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local found_cell = nil
  for _, cell in ipairs(item.table_row.cells) do
    if cell.range:is_in_range(line, col) then
      found_cell = cell
      break
    end
  end

  if found_cell and found_cell.reference then
    return {
      jumpable = true,
      file = found_cell.reference.file,
      file_position = found_cell.reference.range.start_line,
    }
  end
  return {
    jumpable = false,
  }
end

---@param from Date
---@param to Date
---@return ClockReport
function ClockReport.from_date_range(from, to)
  local report = {
    from = from,
    to = to,
    total_duration = 0,
    files = {},
    total_income = 0,
    total_emotion = 0,
    total_invest = 0,
    total_roi = 0,
  }
  local active_cnt = 0
  for _, orgfile in ipairs(Files.all()) do
    local file_clocks = orgfile:get_clock_report(from, to)
    if #file_clocks.headlines > 0 then
      active_cnt = active_cnt + 1
      report.total_duration = report.total_duration + file_clocks.total_duration.minutes
      report.total_income = report.total_income + file_clocks.total_income
      report.total_emotion = report.total_emotion + file_clocks.total_emotion
      report.total_invest = report.total_invest + file_clocks.total_invest
      report.total_roi = report.total_roi + file_clocks.total_roi
      table.insert(report.files, {
        name = orgfile.category .. '.org',
        total_duration = file_clocks.total_duration,
        headlines = file_clocks.headlines,
        total_emotion = file_clocks.total_emotion,
        total_invest = file_clocks.total_invest,
        total_income = file_clocks.total_income,
        total_roi = file_clocks.total_roi,
      })
    end
  end
  if active_cnt == 0 then
    active_cnt = 1
  end
  report.total_roi = report.total_roi / active_cnt
  report.total_duration = Duration.from_minutes(report.total_duration)
  return ClockReport:new(report)
end

return ClockReport
