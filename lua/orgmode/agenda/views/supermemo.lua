local Date = require('orgmode.objects.date')
local Files = require('orgmode.parser.files')
local Range = require('orgmode.parser.range')
local config = require('orgmode.config')
local ClockReport = require('orgmode.clock.report')
local AgendaItem = require('orgmode.agenda.agenda_item')
local AgendaFilter = require('orgmode.agenda.filter')
local utils = require('orgmode.utils')

local function sort_by_date_or_priority_or_category(a, b)
  if a.headline:get_priority_sort_value() ~= b.headline:get_priority_sort_value() then
    return a.headline:get_priority_sort_value() > b.headline:get_priority_sort_value()
  end
  if not a.real_date:is_same(b.real_date, 'day') then
    return a.real_date:is_before(b.real_date)
  end
  return a.index < b.index
end

---@param agenda_items AgendaItem[]
---@return AgendaItem[]
local function sort_agenda_items(agenda_items)
  table.sort(agenda_items, function(a, b)
    return a.real_date.timestamp < b.real_date.timestamp
  end)
  return agenda_items
end

---@class SuperMemoView
---@field span string|number
---@field from Date
---@field to Date
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field clock_report ClockReport
---@field show_clock_report boolean
---@field start_on_weekday number
---@field start_day string
---@field header string
---@field filters AgendaFilter
---@field win_width number
local SuperMemoView = {}

function SuperMemoView:new(opts)
  opts = opts or {}
  local data = {
    content = {},
    highlights = {},
    items = {},
    span = opts.span or config:get_agenda_span(),
    from = opts.from or Date.now():start_of('day'),
    to = nil,
    filters = opts.filters or AgendaFilter:new(),
    clock_report = nil,
    show_clock_report = opts.show_clock_report or false,
    start_on_weekday = opts.org_agenda_start_on_weekday or config.org_agenda_start_on_weekday,
    start_day = opts.org_agenda_start_day or config.org_agenda_start_day,
    header = opts.org_agenda_overriding_header,
    win_width = opts.win_width or utils.winwidth(),
  }

  setmetatable(data, self)
  self.__index = self
  data:_set_date_range()
  return data
end

function SuperMemoView:_get_title()
  if self.header then
    return self.header
  end
  local span = self.span
  if type(span) == 'number' then
    span = string.format('%d days', span)
  end
  local span_number = ''
  if span == 'week' then
    span_number = string.format(' (W%d)', self.from:get_week_number())
  end
  return utils.capitalize(span) .. '-agenda' .. span_number .. ':'
end

function SuperMemoView:_set_date_range(from)
  local span = self.span
  from = from or self.from
  local is_week = span == 'week' or span == '7'
  if is_week and self.start_on_weekday then
    from = from:set_isoweekday(self.start_on_weekday)
  end

  local to = nil
  local modifier = { [span] = 1 }
  if type(span) == 'number' then
    modifier = { day = span }
  end

  to = from:add(modifier)

  if self.start_day and type(self.start_day) == 'string' then
    from = from:adjust(self.start_day)
    to = to:adjust(self.start_day)
  end

  self.span = span
  self.from = from
  self.to = to
end

local function Jump2Top()
  local start_time = Date.now()
  local dates = start_time:get_range_until(start_time:add({ day = 1 }))

  local headline_dates = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:get_opened_headlines()) do
      for _, headline_date in ipairs(headline:get_valid_dates_for_agenda()) do
        table.insert(headline_dates, {
          headline_date = headline_date,
          headline = headline,
        })
      end
    end
  end

  local min_item = nil
  for _, day in ipairs(dates) do
    for index, item in ipairs(headline_dates) do
      if item.headline.todo_keyword.value == 'SUPERMEMO' then
        print(vim.inspect(item.headline_date.timestamp))
        if min_item == nil or item.headline_date.timestamp < min_item.headline_date.timestamp then
          min_item = item
        end
      end
    end
  end

  local item = min_item

  if item == nil then
    vim.notify("Today's card task is complete!", 'success', {
      timeout = 1000 * 10,
      title = 'OrgMode SuperMemo',
    })
    return
  end
  local headline = item.headline

  if utils.current_file_path() ~= headline.file then
    vim.cmd('edit ' .. vim.fn.fnameescape(headline.file))
  end
  vim.fn.cursor({ headline.range.start_line, 0 })

  vim.wo.foldlevel = 1
  vim.cmd([[silent! norm!zx]])

  --for _, section in ipairs(headline.sections) do
  --  --print(vim.inspect(section.title..section.linenumber))
  --  --print(vim.inspect(section))
  --  vim.cmd(section.line_number .. ' foldclose')
  --  --vim.cmd(section.range.start_line .. ',' .. section.range.end_line .. ' fold')
  --end
end

function SuperMemoView:_build_items()
  local dates = self.from:get_range_until(self.to)
  local agenda_days = {}

  local headline_dates = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:get_opened_headlines()) do
      for _, headline_date in ipairs(headline:get_valid_dates_for_agenda()) do
        table.insert(headline_dates, {
          headline_date = headline_date,
          headline = headline,
        })
      end
    end
  end

  for _, day in ipairs(dates) do
    local date = { day = day, agenda_items = {} }

    for index, item in ipairs(headline_dates) do
      local agenda_item = AgendaItem:new(item.headline_date, item.headline, day, index)
      if agenda_item.is_valid and self.filters:matches(item.headline) then
        if item.headline.todo_keyword.value == 'SUPERMEMO' then
          table.insert(date.agenda_items, agenda_item)
        end
      end
    end

    local items = {}
    local all_items = sort_agenda_items(date.agenda_items)
    for index, item in ipairs(all_items) do
      if index > 100 then
        vim.notify("only display first 100 items", 'warn', {
          timeout = 1000 * 10,
          title = 'OrgMode SuperMemo',
        })
        break
      end
      table.insert(items, item)
    end
    date.agenda_items = items
    table.insert(agenda_days, date)
  end

  self.items = agenda_days
end

function SuperMemoView:build()
  self:_build_items()
  local content = { { line_content = self:_get_title() } }
  local highlights = {}
  for _, item in ipairs(self.items) do
    local day = item.day
    local agenda_items = item.agenda_items

    local is_today = day:is_today()
    local is_weekend = day:is_weekend()

    if is_today or is_weekend then
      table.insert(highlights, {
        hlgroup = 'OrgBold',
        range = Range:new({
          start_line = #content + 1,
          end_line = #content + 1,
          start_col = 1,
          end_col = 0,
        }),
      })
    end

    table.insert(content, { line_content = self:_format_day(day) })

    local longest_items = utils.reduce(agenda_items, function(acc, agenda_item)
      acc.category = math.max(acc.category, vim.api.nvim_strwidth(agenda_item.headline:get_category()))
      acc.label = math.max(acc.label, vim.api.nvim_strwidth(agenda_item.label))
      return acc
    end, {
      category = 0,
      label = 0,
    })
    local category_len = math.max(11, (longest_items.category + 1))
    local date_len = math.min(11, longest_items.label)

    -- print(win_width)

    for _, agenda_item in ipairs(agenda_items) do
      table.insert(
        content,
        SuperMemoView.build_agenda_item_content(agenda_item, category_len, date_len, #content, self.win_width)
      )
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'agenda'
  if self.show_clock_report then
    self.clock_report = ClockReport.from_date_range(self.from, self.to)
    utils.concat(self.content, self.clock_report:draw_for_agenda(#self.content + 1))
  end
  return self
end

function SuperMemoView:advance_span(direction, count)
  count = count or 1
  direction = direction * count
  local action = { [self.span] = direction }
  if type(self.span) == 'number' then
    action = { day = self.span * direction }
  end
  self.from = self.from:add(action)
  self.to = self.to:add(action)
  return self:build()
end

function SuperMemoView:change_span(span)
  if span == self.span then
    return
  end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then
      return
    end
  end
  self.span = span
  self:_set_date_range()
  return self:build()
end

function SuperMemoView:goto_date(date)
  self.to = nil
  self:_set_date_range(date)
  self:build()
  vim.schedule(function()
    vim.fn.search(self:_format_day(date))
  end)
end

function SuperMemoView:reset()
  return self:goto_date(Date.now():start_of('day'))
end

function SuperMemoView:toggle_clock_report()
  self.show_clock_report = not self.show_clock_report
  local text = self.show_clock_report and 'on' or 'off'
  utils.echo_info(string.format('Clocktable mode is %s', text))
  return self:build()
end

function SuperMemoView:after_print(_)
  return vim.fn.search(self:_format_day(Date.now()))
end

---@param agenda_item AgendaItem
---@return table
function SuperMemoView.build_agenda_item_content(agenda_item, longest_category, longest_date, line_nr, win_width)
  local headline = agenda_item.headline
  local category = '  ' .. utils.pad_right(string.format('%s:', headline:get_category()), longest_category)
  local date = agenda_item.label
  if date ~= '' then
    date = ' ' .. utils.pad_right(agenda_item.label, longest_date)
  end
  local todo_keyword = agenda_item.headline.todo_keyword.value
  local todo_padding = ''
  if todo_keyword ~= '' and vim.trim(agenda_item.label):find(':$') then
    todo_padding = ' '
  end
  todo_keyword = todo_padding .. todo_keyword
  local line = string.format('%s%s%s %s', category, date, todo_keyword, headline.title)
  local todo_keyword_pos = string.format('%s%s%s', category, date, todo_padding):len()
  if #headline.tags > 0 then
    local tags_string = headline:tags_to_string()
    local padding_length = math.max(1, win_width - vim.api.nvim_strwidth(line) - vim.api.nvim_strwidth(tags_string))
    local indent = string.rep(' ', padding_length)
    line = string.format('%s%s%s', line, indent, tags_string)
  end

  local item_highlights = {}
  if #agenda_item.highlights then
    item_highlights = vim.tbl_map(function(hl)
      hl.range = Range:new({
        start_line = line_nr + 1,
        end_line = line_nr + 1,
        start_col = 1,
        end_col = 0,
      })
      if hl.todo_keyword then
        hl.range.start_col = todo_keyword_pos + 1
        hl.range.end_col = todo_keyword_pos + hl.todo_keyword:len() + 1
      end
      return hl
    end, agenda_item.highlights)
  end

  if headline:is_clocked_in() then
    table.insert(item_highlights, {
      range = Range:new({
        start_line = line_nr + 1,
        end_line = line_nr + 1,
        start_col = 1,
        end_col = 0,
      }),
      hl_group = 'Visual',
      whole_line = true,
    })
  end

  return {
    line_content = line,
    line = line_nr,
    jumpable = true,
    file = headline.file,
    file_position = headline.range.start_line,
    highlights = item_highlights,
    longest_date = longest_date,
    longest_category = longest_category,
    agenda_item = agenda_item,
    headline = headline,
  }
end

function SuperMemoView:_format_day(day)
  return string.format('%-10s %s', day:format('%A'), day:format('%d %B %Y'))
end

return {
  SuperMemoView = SuperMemoView,
  Jump2Top = Jump2Top,
}
