local Files = require('orgmode.parser.files')
local File = require('orgmode.parser.file')
local Table = require('orgmode.parser.table')
local Duration = require('orgmode.objects.duration')

---@class ClockReport
-----@field total_duration Duration
---@field from Date
---@field to Date
---@field total_work_time number
---@field table Table
---@field files table[]
local ClockReport = {}

function ClockReport:new(opts)
  opts = opts or {}
  local data = {}
  data.from = opts.from
  data.to = opts.to
  -- data.total_duration = opts.total_duration
  data.total_work_time = opts.total_work_time
  data.files = opts.files or {}
  data.table = opts.table
  setmetatable(data, self)
  self.__index = self
  return data
end

vim.api.nvim_command('highlight ClockReport guibg=darkred')

local function clearHighLight(groupname)
  local str = [[
       for m in filter(getmatches(), { i, v -> l:v.group is?']] .. groupname .. [[' })
       call matchdelete(m.id)
       endfor
     ]]
  vim.api.nvim_exec(str, true)
end

---@param start_line number
---@return table[]
function ClockReport:draw_for_agenda(start_line)
  clearHighLight('ClockReport')
  local data = {
    { 'File', 'Headline', 'Time' },
    'hr',
    --{ '', 'Total Work time', self.total_duration:to_string() },
    { '', 'Total Work time', tostring(self.total_work_time) },
    'hr',
  }

  for _, file in ipairs(self.files) do
    --table.insert(data, { { value = file.name, reference = file }, 'File time', file.total_duration:to_string() })
    table.insert(data, { { value = file.name, reference = file }, 'File time', tostring(file.total_work_time) })
    for _, headline in ipairs(file.headlines) do
      if File:check_work_time_rule(headline) ~= nil then
        local cut_str = headline.title:gsub('%[', '\\['):gsub('%]', '\\]')
        vim.api.nvim_command(string.format("call matchadd('ClockReport','%s')", cut_str))
      end
      local work_time = headline:get_property('WORK_TIME')
      work_time = work_time or '0'
      table.insert(data, {
        '',
        { value = headline.title, reference = headline },
        work_time,
        --headline.logbook:get_total(self.from, self.to):to_string(),
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
    -- total_duration = 0,
    total_work_time = 0,
    files = {},
  }
  for _, orgfile in ipairs(Files.all()) do
    local file_clocks = orgfile:get_clock_report(from, to)
    if #file_clocks.headlines > 0 then
      --report.total_duration = report.total_duration + file_clocks.total_duration.minutes
      report.total_work_time = report.total_work_time + file_clocks.total_work_time
      table.insert(report.files, {
        name = orgfile.category .. '.org',
        --total_duration = file_clocks.total_duration,
        total_work_time = file_clocks.total_work_time,
        headlines = file_clocks.headlines,
      })
    end
  end
  --report.total_duration = Duration.from_minutes(report.total_duration)
  return ClockReport:new(report)
end

return ClockReport
