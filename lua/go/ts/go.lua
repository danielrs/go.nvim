local nodes = require('go.ts.nodes')

local tsutil = require('nvim-treesitter.ts_utils')
local log = require('go.utils').log
local warn = require('go.utils').warn
local info = require('go.utils').info
local debug = require('go.utils').debug
-- debug = log

local M = {
  query_struct = '(type_spec name:(type_identifier) @definition.struct type: (struct_type))',
  query_package = '(package_clause (package_identifier)@package.name)@package.clause',
  query_struct_id = '(type_spec name:(type_identifier) @definition.struct  (struct_type))',
  query_em_struct_id = '(field_declaration name:(field_identifier) @definition.struct (struct_type))',
  query_struct_block = [[((type_declaration (type_spec name:(type_identifier) @struct.name type: (struct_type)))@struct.declaration)]],
  -- query_type_declaration = [[((type_declaration (type_spec name:(type_identifier)@type_decl.name type:(type_identifier)@type_decl.type))@type_decl.declaration)]], -- rename to gotype so not confuse with type
  query_type_declaration = [[((type_declaration (type_spec name:(type_identifier)@type_decl.name)))]],
  query_em_struct_block = [[(field_declaration name:(field_identifier)@struct.name type: (struct_type)) @struct.declaration]],
  query_struct_block_from_id = [[(((type_spec name:(type_identifier) type: (struct_type)))@block.struct_from_id)]],
  -- query_em_struct = "(field_declaration name:(field_identifier) @definition.struct type: (struct_type))",
  query_interface_id = [[((type_declaration (type_spec name:(type_identifier) @interface.name type:(interface_type)))@interface.declaration)]],
  query_interface_method = [[((method_spec name: (field_identifier)@method.name)@interface.method.declaration)]],
  query_func = '((function_declaration name: (identifier)@function.name) @function.declaration)',
  query_method = '(method_declaration receiver: (parameter_list (parameter_declaration name:(identifier)@method.receiver.name type:(type_identifier)@method.receiver.type)) name:(field_identifier)@method.name)@method.declaration',
  query_method_name = [[((method_declaration
     receiver: (parameter_list)@method.receiver
     name: (field_identifier)@method.name
     body:(block))@method.declaration)]],
  query_method_void = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration)]],
  query_method_multi_ret = [[(method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (parameter_list)@method.result
     body:(block)
     )@method.declaration]],
  query_method_single_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (pointer_type)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration)]],
  query_tr_method_void = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     body:(block)
  )@method.declaration)]],
  query_tr_method_multi_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (parameter_list)@method.result
     body:(block)
     )@method.declaration)]],
  query_tr_method_single_ret = [[((method_declaration
     receiver: (parameter_list
       (parameter_declaration
         name: (identifier)@method.receiver.name
         type: (type_identifier)@method.receiver.type)
       )
     name: (field_identifier)@method.name
     parameters: (parameter_list)@method.parameter
     result: (type_identifier)@method.result
     body:(block)
     )@method.declaration)]],
  query_test_func = [[((function_declaration name: (identifier) @test_name
        parameters: (parameter_list
            (parameter_declaration
                     name: (identifier)
                     type: (pointer_type
                         (qualified_type
                          package: (package_identifier) @_param_package
                          name: (type_identifier) @_param_name))))
         ) @testfunc
      (#contains? @test_name "Test")
      (#match? @_param_package "testing")
      (#match? @_param_name "T"))]],
  query_testcase_node = [[(literal_value (literal_element (literal_value .(keyed_element (literal_element (identifier)) (literal_element (interpreted_string_literal) @test.name)))))]],
  query_string_literal = [[((interpreted_string_literal) @string.value)]],
}

local function get_name_defaults()
  return { ['func'] = 'function', ['if'] = 'if', ['else'] = 'else', ['for'] = 'for' }
end

M.get_struct_node_at_pos = function(bufnr)
  local query = M.query_struct_block .. ' ' .. M.query_em_struct_block
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('struct not found')
  else
    log('struct node', ns)
    return ns[#ns]
  end
end

M.get_type_node_at_pos = function(bufnr)
  local query = M.query_type_declaration
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('type not found')
  else
    log('type node', ns)
    return ns[#ns]
  end
end

M.get_interface_node_at_pos = function(bufnr)
  local query = M.query_interface_id

  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    debug('interface not found')
  else
    return ns[#ns]
  end
end

M.get_interface_method_node_at_pos = function(bufnr)
  local query = M.query_interface_method
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufnr)
  if ns == nil then
    warn('interface method not found')
  else
    return ns[#ns]
  end
end

M.get_func_method_node_at_pos = function(bufnr)
  local query = M.query_func .. ' ' .. M.query_method_name
  -- local query = require("go.ts.go").query_method_name

  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    return nil
  end
  if ns == nil then
    warn('function not found')
  else
    return ns[#ns]
  end
end

M.get_testcase_node = function(bufnr)
  local query = M.query_testcase_node
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, 'name')
  if ns == nil then
    debug('test case not found')
  else
    log('testcase node', ns[#ns])
    return ns[#ns]
  end
end

M.get_string_node = function(bufnr)
  local query = M.query_string_literal
  local bufn = bufnr or vim.api.nvim_get_current_buf()
  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn, 'value')
  if ns == nil then
    debug('struct not found')
  else
    log('struct node', ns[#ns])
    return ns[#ns]
  end
end

M.get_import_node_at_pos = function(bufnr)
  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local cur_node = tsutil.get_node_at_cursor()

  if cur_node and (cur_node:type() == 'import_spec' or cur_node:parent():type() == 'import_spec') then
    return cur_node
  end
end

M.get_module_at_pos = function(bufnr)
  local node = M.get_import_node_at_pos(bufnr)
  if node then
    local module = require('go.utils').get_node_text(node, vim.api.nvim_get_current_buf())
    -- log
    module = string.gsub(module, '"', '')
    return module
  end
end

M.get_package_node_at_pos = function(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row, col = row, col + 1
  if row > 10 then
    return
  end
  local query = M.query_package
  -- local query = require("go.ts.go").query_method_name

  local bufn = bufnr or vim.api.nvim_get_current_buf()

  local ns = nodes.nodes_at_cursor(query, get_name_defaults(), bufn)
  if ns == nil then
    return nil
  end
  if ns == nil then
    warn('package not found')
  else
    return ns[#ns]
  end
end

function M.in_func()
  local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  if not ok then
    return false
  end
  local current_node = ts_utils.get_node_at_cursor()
  if not current_node then
    return false
  end
  local expr = current_node

  while expr do
    if expr:type() == 'function_declaration' or expr:type() == 'method_declaration' then
      return true
    end
    expr = expr:parent()
  end
  return false
end

return M
