local utils = require('orgmode.utils')
---@class AgendaFilter
---@field value string
---@field available_tags table<string, boolean>
---@field available_categories table<string, boolean>
---@field filter_type 'include' | 'exclude'
---@field tags table[]
---@field categories table[]
---@field term string
---@field parsed boolean
---@field applying boolean
local AgendaFilter = {}

function AgendaFilter:new()
  local data = {
    value = '',
    available_status = {},
    available_tags = {},
    available_categories = {},
    filter_type = 'exclude',
    status = {},
    tags = {},
    categories = {},
    term = '',
    parsed = false,
    applying = false,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@return boolean
function AgendaFilter:should_filter()
  return vim.trim(self.value) ~= ''
end

---@param headline Section
---@return boolean
function AgendaFilter:matches(headline)
  if not self:should_filter() then
    return true
  end
  local term_match = vim.trim(self.term) == ''
  local tag_cat_sta_match_empty = #self.tags == 0 and #self.categories == 0 and #self.status == 0

  if not term_match then
    local rgx = vim.regex(self.term)
    term_match = rgx:match_str(headline.title)
  end

  if tag_cat_sta_match_empty then
    return term_match
  end

  local tag_cat_sta_match = false

  if self.filter_type == 'include' then
    tag_cat_sta_match = self:_matches_include(headline)
  else
    tag_cat_sta_match = self:_matches_exclude(headline)
  end

  return tag_cat_sta_match and term_match
end

---@param headline Section
---@private
function AgendaFilter:_matches_exclude(headline)
  -- print("exclude")
  for _, tag in ipairs(self.tags) do
    if headline:has_tag(tag.value) then
      return false
    end
  end

  for _, category in ipairs(self.categories) do
    if headline:matches_category(category.value) then
      return false
    end
  end

  for _, status in ipairs(self.status) do
    --print(headline.title..headline.todo_keyword.value..status.value)
    if headline.todo_keyword.value == status.value then
      return false
    end
  end
  return true
end

---@param headline Section
---@private
function AgendaFilter:_matches_include(headline)
  local tags_to_check = {}
  local categories_to_check = {}
  local status_to_check = {}

  for _, tag in ipairs(self.tags) do
    if tag.operator == '-' then
      if headline:has_tag(tag.value) then
        return false
      end
    else
      table.insert(tags_to_check, tag.value)
    end
  end

  for _, category in ipairs(self.categories) do
    if category.operator == '-' then
      if headline:matches_category(category.value) then
        return false
      end
    else
      table.insert(categories_to_check, category.value)
    end
  end

  for _, status in ipairs(self.status) do
    if status.operator == '-' then
      if headline.todo_keyword.value == status.value then
        return false
      end
    else
      table.insert(status_to_check, status.value)
    end
  end

  local tags_passed = #tags_to_check == 0
  local categories_passed = #categories_to_check == 0
  local status_passed = #status_to_check == 0

  for _, category in ipairs(categories_to_check) do
    if headline:matches_category(category) then
      categories_passed = true
      break
    end
  end

  for _, tag in ipairs(tags_to_check) do
    if headline:has_tag(tag) then
      tags_passed = true
      break
    end
  end

  for _, status in ipairs(status_to_check) do
    if headline.todo_keyword.value == status then
      status_passed = true
      break
    end
  end

  return tags_passed and categories_passed and status_passed
end

---@param filter string
---@param skip_check? boolean do not check if given values exist in the current view
function AgendaFilter:parse(filter, skip_check)
  filter = filter or ''
  self.value = filter
  self.tags = {}
  self.categories = {}
  self.status = {}
  local search_rgx = '/[^/]*/?'
  local search_term = filter:match(search_rgx)
  if search_term then
    search_term = search_term:gsub('^/*', ''):gsub('/*$', '')
  end
  filter = filter:gsub(search_rgx, '')
  for operator, tag_cat_sta in string.gmatch(filter, '([%+%-]*)([^%-%+]+)') do
    if not operator or operator == '' or operator == '+' then
      self.filter_type = 'include'
    end
    local val = vim.trim(tag_cat_sta)
    if val ~= '' then
      if self.available_tags[val] or skip_check then
        table.insert(self.tags, { operator = operator, value = val })
      elseif self.available_categories[val] or skip_check then
        table.insert(self.categories, { operator = operator, value = val })
      elseif self.available_status[val] or skip_check then
        table.insert(self.status, { operator = operator, value = val })
      end
    end
  end
  self.term = search_term or ''
  self.applying = true
  if skip_check then
    self.parsed = true
  end
end

function AgendaFilter:reset()
  self.value = ''
  self.term = ''
  self.parsed = false
  self.applying = false
end

---@param content table[]
function AgendaFilter:parse_tags_and_categories_and_status(content)
  if self.parsed then
    return
  end
  local status = {}
  local tags = {}
  local categories = {}
  for _, item in ipairs(content) do
    if item.jumpable and item.headline then
      categories[item.headline.category:lower()] = true
      for _, tag in ipairs(item.headline.tags) do
        tags[tag:lower()] = true
      end
      status[item.headline.todo_keyword.value] = true
    end
  end
  self.available_tags = tags
  self.available_categories = categories
  self.available_status = status
  self.parsed = true
end

---@return string[]
function AgendaFilter:get_completion_list()
  local list = utils.concat(vim.tbl_keys(self.available_tags), vim.tbl_keys(self.available_categories), true)
  return utils.concat(vim.tbl_keys(self.available_status), list, true)
end

return AgendaFilter
