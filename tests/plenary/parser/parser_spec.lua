local parser = require('orgmode.parser')

describe('Parser', function()
  it('should parse lines', function()
    local lines = {
      'Top level content',
      '* TODO Test orgmode',
      '** TODO Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT inherits tags without duplicates :OFFICE:NESTED:',
      '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
    }

    local parsed = parser.parse(lines)
    assert.are.same({
      content = {},
      headlines = { 3 },
      level = 1,
      line = "* TODO Test orgmode",
      line_nr = 2,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'TODO',
      tags = {},
    }, parsed.items[2])
    assert.are.same({
      content = { 4 },
      headlines = { 5 },
      level = 2,
      line = "** TODO Test orgmode level 2 :PRIVATE:",
      line_nr = 3,
      parent = 2,
      type = "HEADLINE",
      todo_keyword = 'TODO',
      tags = {'PRIVATE'},
    }, parsed.items[3])
    assert.are.same({
      level = 2,
      line = "Some content for level 2",
      line_nr = 4,
      parent = 3,
      type = "CONTENT",
    }, parsed.items[4])
    assert.are.same({
      content = { 6 },
      headlines = {},
      level = 3,
      line = "*** NEXT Level 3",
      line_nr = 5,
      parent = 3,
      type = "HEADLINE",
      todo_keyword = 'NEXT',
      tags = {'PRIVATE'},
    }, parsed.items[5])
    assert.are.same({
      level = 3,
      line = "Content Level 3",
      line_nr = 6,
      parent = 5,
      type = "CONTENT",
    }, parsed.items[6])
    assert.are.same({
      content = { 8 },
      headlines = {},
      level = 1,
      line = "* DONE top level todo :WORK:",
      line_nr = 7,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'DONE',
      tags = {'WORK'},
    }, parsed.items[7])
    assert.are.same({
      level = 1,
      line = "content for top level todo",
      line_nr = 8,
      parent = 7,
      type = "CONTENT",
    }, parsed.items[8])
    assert.are.same({
      content = { 10 },
      headlines = { 11 },
      level = 1,
      line = "* TODO top level todo with multiple tags :OFFICE:PROJECT:",
      line_nr = 9,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'TODO',
      tags = {'OFFICE', 'PROJECT'},
    }, parsed.items[9])
    assert.are.same({
      level = 1,
      line = "multiple tags content, tags not read from content :FROMCONTENT:",
      line_nr = 10,
      parent = 9,
      type = "CONTENT",
    }, parsed.items[10])
    assert.are.same({
      content = {},
      headlines = {},
      level = 2,
      line = "** NEXT inherits tags without duplicates :OFFICE:NESTED:",
      line_nr = 11,
      parent = 9,
      type = "HEADLINE",
      todo_keyword = 'NEXT',
      tags = {'OFFICE', 'PROJECT', 'NESTED'},
    }, parsed.items[11])
    assert.are.same({
      content = {},
      headlines = {},
      level = 1,
      line = "* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:",
      line_nr = 12,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = '',
      tags = {},
    }, parsed.items[12])
    assert.are.same(parsed.level, 0)
    assert.are.same(parsed.line_nr, 0)
    assert.are.same(parsed.lines, lines)
  end)
end)
