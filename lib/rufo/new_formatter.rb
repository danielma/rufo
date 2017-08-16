# frozen_string_literal: true

require "ripper"
require "awesome_print"

module Rufo
  class NewFormatter
    def self.format(code, **options)
      formatter = new(code, **options)
      formatter.format
      formatter.result
    end

    def initialize(code, **options)
      @code = code
      @tokens = Ripper.lex(code).reverse!
      @sexp = Ripper.sexp(code)

      unless @sexp
        raise ::Rufo::SyntaxError.new
      end

      @indent_size = 2
      @line_length = options.fetch(:line_length, 80)

      @indent = 0
      @column = 0
      @last_was_newline = true
      @output = "".dup

      # the current group
      @group = nil

      # heredocs that are waiting to be flushed
      @heredocs = []
    end

    def format
      visit @sexp
      flush_heredocs
      consume_end
    end

    def result
      @output
    end

    private

    def visit(node)
      unless node.is_a?(Array)
        bug "Expected array node, but found: #{node} at #{current_token}"
      end

      case node.first
      when :program
        # Topmost node
        #
        # [:program, exps]
        visit_exps node[1] #, with_indent: true
      when :string_literal, :xstring_literal
        visit_string_literal(node)
      when :string_content
        # [:string_content, exp]
        visit_exps node[1..-1], with_lines: false
      when :@tstring_content
        # [:@tstring_content, "hello", [1, 1]]
        consume_token :on_tstring_content
      when :@const
        # [:@const, "FOO", [1, 0]]
        consume_token :on_const
      when :@gvar
        # [:@gvar, "$abc", [1, 0]]
        write node[1]
        move_to_next_token
      when :@op
        # [:@op, "*", [1, 1]]
        write node[1]
        move_to_next_token
      when :const_ref
        # [:const_ref, [:@const, "Foo", [1, 8]]]
        visit node[1]
      when :top_const_ref
        # [:top_const_ref, [:@const, "Foo", [1, 2]]]
        consume_op "::"
        skip_space_or_newline
        visit node[1]
      when :top_const_field
        # [:top_const_field, [:@const, "Foo", [1, 2]]]
        consume_op "::"
        visit node[1]
      when :string_embexpr
        visit_string_interpolation(node)
      when :vcall
        # [:vcall, exp]
        visit node[1]
      when :fcall
        # [:fcall, [:@ident, "foo", [1, 0]]]
        visit node[1]
      when :command
        visit_command(node)
      when :command_call
        visit_command_call(node)
      when :@ident
        # [:@ident, "meth", [1, 2]]
        consume_token :on_ident
      when :@cvar
        # [:@cvar, "@@foo", [1, 0]]
        consume_token :on_cvar
      when :@kw
        # [:@kw, "nil", [1, 0]]
        consume_token :on_kw
      when :@ivar
        # [:@ivar, "@foo", [1, 0]]
        consume_token :on_ivar
      when :const_path_ref
        visit_path(node)
      when :const_path_field
        visit_path(node)
      when :assign
        visit_assign(node)
      when :opassign
        visit_op_assign(node)
      when :massign
        visit_multiple_assign(node)
      when :var_field
        # [:var_field, exp]
        visit node[1]
      when :def
        visit_def(node)
      when :paren
        visit_paren(node)
      when :bodystmt
        visit_bodystmt(node)
      when :if
        visit_if(node)
      when :unless
        visit_unless(node)
      when :if_mod
        visit_suffix(node, "if")
      when :case
        visit_case(node)
      when :when
        visit_when(node)
      when :var_ref
        # [:var_ref, exp]
        visit node[1]
      when :params
        visit_params(node)
      when :void_stmt
        # [:void_stmt]
        skip_space_or_newline
      when :hash
        visit_hash(node)
      when :array
        visit_array(node)
      when :assoc_new
        visit_hash_key_value(node)
      when :break
        # [:break, exp]
        visit_control_keyword node, "break"
      when :next
        # [:next, exp]
        visit_control_keyword node, "next"
      when :yield
        # [:yield, exp]
        visit_control_keyword node, "yield"
      when :return
        # [:return, exp]
        visit_control_keyword node, "return"
      when :defined
        visit_defined(node)
      when :yield0
        consume_keyword "yield"
      when :return0
        consume_keyword "return"
      when :assoc_splat
        visit_splat_inside_hash(node)
      when :dyna_symbol
        visit_quoted_symbol_literal(node)
      when :binary
        visit_binary(node)
      when :unary
        visit_unary(node)
      when :@label
        # [:@label, "foo:", [1, 3]]
        write node[1]
        check :on_label
        move_to_next_token
      when :class
        visit_class(node)
      when :module
        visit_module(node)
      when :sclass
        visit_sclass(node)
      when :symbol_literal
        # [:symbol_literal, [:symbol, [:@ident, "foo", [1, 1]]]]
        #
        # A symbol literal not necessarily begins with `:`.
        # For example, an `alias foo bar` will treat `foo`
        # a as symbol_literal but without a `:symbol` child.
        visit node[1]
      when :symbol
        # [:symbol, [:@ident, "foo", [1, 1]]]
        consume_token :on_symbeg
        visit_exps node[1..-1], with_lines: false
      when :@int
        # Integer literal
        #
        # [:@int, "123", [1, 0]]
        consume_token :on_int
      when :begin
        visit_begin(node)
      when :mrhs_new_from_args
        visit_mrhs_new_from_args(node)
      when :args_add_star
        visit_args_add_star(node)
      when :bare_assoc_hash
        # [:bare_assoc_hash, exps]
        visit_comma_separated_list node[1]
      when :method_add_arg
        visit_call_without_receiver(node)
      when :call
        visit_call_with_receiver(node)
      when :BEGIN
        visit_BEGIN(node)
      when :END
        visit_END(node)
      when :alias, :var_alias
        visit_alias(node)
      when :aref
        visit_array_access(node)
      when :args_add_block
        visit_call_args(node)
      when :aref_field
        visit_array_setter(node)
      when :method_add_block
        visit_call_with_block(node)
      when :fcall
        # [:fcall, [:@ident, "foo", [1, 0]]]
        visit node[1]
      when :brace_block
        visit_brace_block(node)
      when :block_var
        visit_block_arguments(node)
      when :mlhs_paren
        visit_mlhs_paren(node)
      when :command
        visit_command(node)
      when :do_block
        visit_do_block(node)
      else
        bug "Unhandled node: #{node.first} at #{current_token}"
      end
    end

    # Visit an array of expressions
    #
    # - with_lines:             consume whole line for each expression
    # - allow_trailing_newline: allow a trailing newline
    def visit_exps(exps, with_lines: true, allow_trailing_newline: true)
      consume_end_of_line(at_prefix: true)

      exps.each_with_index do |exp, i|
        expression_context do
          indent(@indent) do
            group(:exp) { visit exp }
          end
        end

        is_last = last?(i, exps)

        if with_lines
          needs_two_lines = !is_last && needs_two_lines?(exps[i + 1])

          if exp == [:void_stmt] || (is_last && !allow_trailing_newline)
            skip_space_or_newline
          else
            consume_end_of_line(want_multiline: !is_last && !needs_two_lines)
          end

          # Make sure to put two lines before defs, class and others
          if needs_two_lines
            write_breaking_hardline
          end
        end
      end
    end

    # Consume and print an end of line, handling semicolons and comments
    #
    # - at_prefix: are we at a point before an expression? (if so, we don't need a space before the first comment)
    # - want_multiline: do we want multiple lines to appear, or at most one?
    def consume_end_of_line(at_prefix: false, want_multiline: true)
      multiple_lines = false                   # Did we pass through more than one newline?
      last = last_is_newline? ? :newline : nil # last token kind found
      found_newline = last == :newline         # Did we find any newline during this method?
      debug("consume_end_of_line: begin. at_prefix: #{at_prefix}")

      loop do
        debug("consume_end_of_line: start #{current_token_kind} #{current_token_value.inspect}")
        case current_token_kind
        when :on_nl, :on_semicolon, :on_ignored_nl
          if at_prefix
            last = :newline
            move_to_next_token
            next
          elsif last == :newline
            multiple_lines = true
          else
            write_breaking_hardline
          end

          move_to_next_token
          last = :newline
          found_newline = true
        when :on_sp
          # ignore spaces
          move_to_next_token
        when :on_comment
          if !at_prefix && multiple_lines
            write_breaking_hardline
            found_newline = false
            multiple_lines = false
          end

          handle_comment

          if current_token_value.end_with?("\n")
            write_breaking_hardline 
            found_newline = true
          end

          move_to_next_token

          consume_ignored_newlines_as_one

          consume_end_of_line(at_prefix: at_prefix, want_multiline: want_multiline)
          break
        else
          debug("consume_end_of_line: end #{current_token_kind}")
          break
        end
      end

      # Output a newline if we didn't do so yet:
      # either we didn't find a newline and we are at the end of a line (and we didn't just pass a semicolon),
      # or we just passed multiple lines (but printed only one)
      if !at_prefix && want_multiline && (!found_newline || multiple_lines)
        debug "consume_end_of_line: needs an extra newline"
        write_breaking_hardline
      end
    end

    def consume_ignored_newlines_as_one
      needs_extra_newline = false

      while current_token_kind == :on_ignored_nl
        needs_extra_newline = true
        move_to_next_token
      end

      write_breaking_hardline if needs_extra_newline
    end

    # Skip spaces and newlines
    def skip_space_or_newline
      skipped_one_newline = false
      skipped_empty_line = false

      loop do
        debug("skip_space_or_newline: start #{current_token_kind} #{current_token_value}")
        case current_token_kind
        when :on_nl, :on_ignored_nl
          skipped_empty_line = skipped_one_newline
          skipped_one_newline = true
          move_to_next_token
        when :on_sp, :on_semicolon
          move_to_next_token
        when :on_comment
          write_breaking_hardline if skipped_empty_line

          handle_comment(trailing: !skipped_one_newline)
          move_to_next_token
        else
          debug("skip_space_or_newline: end #{current_token_kind} #{current_token_value}")
          break
        end
      end
    end

    def handle_comment(trailing: true)
      value = current_comment_value.rstrip

      if @group
        if trailing
          write_trailing value
        else
          write_breaking_hardline
          write value
        end

        write_breaking
      else
        write " " unless last_is_newline?
        write value
      end
    end

    def current_comment_value
      check :on_comment

      value = current_token_value

      if value =~ /^#[^\s]/
        "# #{value[1..-1]}"
      else
        value
      end
    end

    def visit_begin(node)
      # [:begin, [:bodystmt, body, rescue_body, else_body, ensure_body]]
      _, body_statement = node
      _, _body, rescue_body, _else_body, ensure_body = body_statement

      indent_level = if rescue_body || ensure_body
                       @column
                     else
                       @indent
                     end

      indent(indent_level) do
        consume_keyword "begin"

        if body_statement_empty?(body_statement)
          write "; "
          visit body_statement
        else
          write_breaking_hardline
          visit body_statement
        end
      end
    end

    def visit_string_literal(node)
      # [:string_literal, [:string_content, exps]]
      case current_token_kind
      when :on_backtick
        consume_token :on_backtick
      when :on_heredoc_beg
        @heredocs.unshift(node)
        consume_token :on_heredoc_beg
        # Accumulate heredoc: we'll write it once
        # we find a newline.
        return
      else
        consume_token :on_tstring_beg
      end

      visit_string_literal_end(node)
    end

    def visit_string_literal_end(node)
      # [:string_literal, [:string_content, exps]]
      inner = node[1]
      inner = inner[1..-1] unless node[0] == :xstring_literal

      visit_exps(inner, with_lines: false)

      case current_token_kind
      when :on_backtick
        consume_token :on_backtick
      when :on_heredoc_end
        write current_token_value
        move_to_next_token
        @tokens << [[0, 0], :on_ignored_nl, "\n"]
      else
        consume_token :on_tstring_end
      end
    end

    def visit_string_interpolation(node)
      # [:string_embexpr, exps]
      consume_token :on_embexpr_beg
      skip_space_or_newline
      visit_exps(node[1], with_lines: false)
      skip_space_or_newline
      consume_token :on_embexpr_end
    end

    def visit_path(node)
      # Foo::Bar
      #
      # [:const_path_ref,
      #   [:var_ref, [:@const, "Foo", [1, 0]]],
      #   [:@const, "Bar", [1, 5]]]
      _, *pieces = node

      pieces.each_with_index do |piece, i|
        visit piece
        unless last?(i, pieces)
          consume_op "::"
          skip_space_or_newline
        end
      end
    end

    def visit_assign_value(value)
      skip_space_or_newline

      if %i(on_int on_tstring_beg).include?(current_token_kind)
        write_line
        indent do
          visit(value)
        end
      elsif %w(case if unless).include?(current_token_value)
        write " "
        indent(@column) do
          visit value
        end
      else
        write " "
        visit value
      end
    end

    def visit_command(node)
      # foo arg1, ..., argN
      #
      # [:command, name, args]
      _, name, args = node

      visit name
      consume_space
      visit args
    end

    def visit_command_call(node)
      # [:command_call,
      #   receiver
      #   :".",
      #   name
      #   [:args_add_block, [[:@int, "1", [1, 8]]], block]]
      _, receiver, dot, name, args = node

      @expression_context.chained_call_count += 1

      visit receiver

      write_softline

      indent do
        consume_token :on_period
        visit name
        write_if_break("(", " ")

        indent do
          write_softline
          visit_exps to_ary(args), with_lines: false
          write_if_break(",", "")
          write_softline
        end

        write_if_break(")", "")
      end
    end

    def visit_assign(node)
      # [:assign, target, value]
      _, target, value = node

      visit(target)

      consume_space
      consume_op "="

      visit_assign_value(value)
    end

    def indentable_value?(value)
      return unless current_token_kind == :on_kw

      case current_token_value
      when "if", "unless", "case"
        true
      when "begin"
        # Only indent if it's begin/rescue
        return false unless value[0] == :begin

        body = value[1]
        return false unless body[0] == :bodystmt

        _, body, rescue_body, else_body, ensure_body = body
        rescue_body || else_body || ensure_body
      else
        false
      end
    end

    def visit_def(node)
      # [:def,
      #   [:@ident, "foo", [1, 6]],
      #   [:params, nil, nil, nil, nil, nil, nil, nil],
      #   [:bodystmt, [[:void_stmt]], nil, nil, nil]]
      _, name, params, body = node

      params = params[1] if params[0] == :paren

      consume_keyword "def"
      consume_space

      visit name

      skip_space

      if current_token_kind == :on_lparen
        move_to_next_token
        skip_space
      end

      if !empty_params?(params)
        group do
          write "("
          write_softline

          indent do
            visit params
          end

          write_softline
          write ")"
          move_to_next_token
        end
      end

      write_if_break(HARDLINE, "; ")

      visit body
    end

    def visit_op_assign(node)
      # target += value
      #
      # [:opassign, target, op, value]
      _, target, op, value = node

      group do
        visit target
        consume_space

        # [:@op, "+=", [1, 2]],
        check :on_op

        write op[1]
        move_to_next_token

        visit_assign_value value
      end
    end

    def visit_multiple_assign(node)
      # [:massign, lefts, right]
      _, lefts, right = node

      group do
        visit_comma_separated_list lefts

        first_space = skip_space

        # A trailing comma can come after the left hand side
        if comma?
          consume_token :on_comma
          first_space = skip_space
        end

        write " "
        consume_op "="
        visit_assign_value right
      end
    end

    def empty_params?(node)
      _, a, b, c, d, e, f, g = node
      !a && !b && !c && !d && !e && !f && !g
    end

    def visit_paren(node)
      # ( exps )
      #
      # [:paren, exps]
      _, exps = node

      consume_token :on_lparen
      skip_space_or_newline
      write_softline

      if exps
        indent do
          exps = to_ary(exps)
          visit_exps exps, with_lines: !exps.one?
        end
      end

      skip_space_or_newline
      consume_token :on_rparen
    end

    def visit_bodystmt(node)
      # [:bodystmt, body, rescue_body, else_body, ensure_body]
      _, body, rescue_body, else_body, ensure_body = node

      body = body_without_void_statements(body)

      if body.empty?
        skip_space_or_newline
      else
        write_breaking
        indent_body(body)
      end

      # [:rescue, type, name, body, more_rescue]
      while rescue_body
        _, type, name, body, more_rescue = rescue_body

        consume_keyword "rescue"

        if type
          skip_space
          write(" ")
          visit_rescue_types(type)
        end

        if name
          consume_space
          consume_op "=>"
          consume_space
          visit(name)
        end

        indent do
          consume_end_of_line
          visit_exps body
        end

        rescue_body = more_rescue
      end

      if ensure_body
        # [:ensure, body]
        consume_keyword "ensure"
        write_breaking_hardline
        indent_body ensure_body[1]
      end

      consume_keyword "end"
    end

    def visit_rescue_types(node)
      group do
        visit_exps to_ary(node), with_lines: false
      end
    end

    def visit_defined(node)
      # [:defined, exp]
      _, exp = node

      consume_keyword "defined?"


      has_space = space?
      has_paren = current_token_kind == :on_lparen

      skip_space_or_newline

      if has_paren && !has_space
        consume_token :on_lparen
        skip_space_or_newline
      else
        write " "
      end

      visit exp

      if has_paren && !has_space
        skip_space_or_newline
        consume_token :on_rparen
      end
    end

    def visit_if(node)
      visit_if_or_unless("if", node)
    end

    def visit_unless(node)
      visit_if_or_unless("unless", node)
    end

    def visit_if_or_unless(keyword, node)
      # if cond
      #   then_body
      # else
      #   else_body
      # end
      #
      # [:if, cond, then, else]
      _, condition, body, else_clause = node

      consume_keyword(keyword)
      consume_space
      visit condition

      indent do
        skip_space_or_newline
        move_to_next_token if keyword?("then")
        skip_space_or_newline
        write_breaking_hardline

        visit_exps body
        write_hardline unless last_is_newline?
      end

      if else_clause
        # [:else, body]
        # [:elsif, cond, body]
        kind, else_body = else_clause
        cond = nil

        bug "expected else or elsif, not #{kind}" unless %i(else elsif).include?(kind)

        if kind == :elsif
          _, cond, else_body = else_clause
        elsif else_body != [[:void_stmt]]
          consume_keyword "else"
        end

        if cond
          consume_keyword "elsif"
          consume_space
          skip_space_or_newline
          visit cond
        end

        if else_body != [[:void_stmt]]
          indent do
            skip_space_or_newline
            write_breaking_hardline

            visit_exps else_body, allow_trailing_newline: false
            write_hardline
          end
        else
          move_to_next_token
        end
      end

      skip_space_or_newline
      consume_keyword "end"
    end

    def visit_suffix(node, suffix)
      # then if cond
      # then unless cond
      # exp rescue handler
      #
      # [:if_mod, cond, body]
      _, body, cond = node

      if suffix != "rescue"
        body, cond = cond, body
      end

      visit body
      consume_space
      consume_keyword(suffix)
      consume_space
      visit cond
    end

    def visit_case(node)
      # [:case, cond, case_when]
      _, cond, case_when = node

      consume_keyword "case"

      if cond
        consume_space
        visit cond
      end

      consume_end_of_line

      visit case_when

      consume_keyword "end"
    end

    def visit_when(node)
      # [:when, conds, body, next_exp]
      _, conds, body, next_exp = node

      group(:case_when) do
        consume_keyword "when"
        consume_space

        indent(@column) do
          group(:when_conditions) do
            visit_comma_separated_list conds
          end
        end

        indent do
          skip_space_or_newline

          then_keyword = keyword?("then")
          if then_keyword
            move_to_next_token
            write_if_break(HARDLINE, " then ")
          else
            write_breaking_hardline
          end

          skip_space_or_newline

          body = body_without_void_statements(body)

          if !body.empty?
            visit_exps body, allow_trailing_newline: false
            skip_space_or_newline

            write_hardline
          end
        end

        if next_exp
          if next_exp.first == :else
            # [:else, body]
            _, body = next_exp

            consume_keyword "else"
            skip_space_or_newline
            write_line
            body = body_without_void_statements(body)
            indent do
              visit_exps body, with_lines: body.count > 1
            end
            skip_space_or_newline
            write_hardline
          else
            visit next_exp
          end
        end
      end
    end

    def visit_mrhs_new_from_args(node)
      # Multiple exception types
      # [:mrhs_new_from_args, exps, final_exp]
      _, exps, final_exp = node

      if final_exp
        visit_comma_separated_list exps
        write_params_comma
        visit final_exp
      else
        visit_comma_separated_list to_ary(exps)
      end
    end

    def visit_args_add_star(node)
      # [:args_add_star, args, star, post_args]
      _, args, star, *post_args = node

      if !args.empty? && args[0] == :args_add_star
        # arg1, ..., *star
        visit args
      else
        visit_comma_separated_list args
      end

      skip_space

      write_params_comma if comma?

      consume_op "*"
      skip_space_or_newline
      visit star

      if post_args && !post_args.empty?
        write_params_comma
        visit_comma_separated_list post_args
      end
    end

    def visit_call_without_receiver(node)
      # foo(arg1, ..., argN)
      #
      # [:method_add_arg,
      #   [:fcall, [:@ident, "foo", [1, 0]]],
      #   [:arg_paren, [:args_add_block, [[:@int, "1", [1, 6]]], false]]]
      _, name, args = node

      visit name

      group(:visit_call_at_paren) do
        consume_token :on_lparen
        write_softline

        # If there's a trailing comma then comes [:arg_paren, args],
        # which is a bit unexpected, so we fix it
        if args[1].is_a?(Array) && args[1][0].is_a?(Array)
          args_node = [:args_add_block, args[1], false]
        else
          args_node = args[1]
        end

        if args_node
          indent do
            visit(args_node)
          end
        end

        move_to_next_token if comma?

        write_if_break(",", "")

        skip_space_or_newline

        write_softline unless last_is_newline?

        consume_token :on_rparen
        set_indent(@expression_context.dot_indent - @indent_size)
      end
    end

    def visit_call_with_receiver(node)
      # [:call, obj, :".", name]
      _, obj, text, name = node

      @expression_context.chained_call_count += 1
      obj_is_method_call = (obj[0] == :call || obj[0] == :method_add_arg)

      needs_softline = obj_is_method_call || (@expression_context.chained_call_count > 1)

      visit obj
      skip_space_or_newline

      if needs_softline
        set_indent(@expression_context.dot_indent)
        write_softline
      end

      consume_token :on_period
      skip_space_or_newline

      # :call means it's .()
      visit name if name != :call
    end

    def visit_BEGIN(node)
      visit_BEGIN_or_END node, "BEGIN"
    end

    def visit_END(node)
      visit_BEGIN_or_END node, "END"
    end

    def visit_BEGIN_or_END(node, keyword)
      # [:BEGIN, body]
      _, body = node

      consume_keyword(keyword)
      consume_space

      # If the whole block fits into a single line, format
      # in a single line
      group(:BEGIN_or_END) do
        consume_token :on_lbrace

        indent do
          skip_space_or_newline
          write_breaking_hardline
          visit_exps body, with_lines: true
          consume_end_of_line
        end

        consume_token :on_rbrace
      end
    end

    def visit_alias(node)
      # [:alias, from, to]
      _, from, to = node

      consume_keyword "alias"
      consume_space
      visit from
      consume_space
      visit to
    end

    def visit_params(node)
      # [:params, pre_rest_params, args_with_default, rest_param, post_rest_params, label_params, double_star_param, blockarg]
      _, pre_rest_params, args_with_default, rest_param, post_rest_params, label_params, double_star_param, blockarg = node

      visit_comma_separated_list pre_rest_params
    end

    def visit_comma_separated_list(nodes)
      nodes = to_ary(nodes)

      consume_end_of_line(at_prefix: true)

      nodes.each_with_index do |exp, i|
        visit exp

        if last?(i, nodes)
          skip_space
          move_to_next_token if comma?
          skip_space
          next
        end

        skip_space
        consume_token :on_comma
        skip_space_or_newline
        write_line
      end
    end

    def visit_hash(node)
      # [:hash, elements]
      _, elements = node

      check :on_lbrace
      group(:hash) do
        write "{"
        move_to_next_token

        if elements
          indent do
            # [:assoclist_from_args, elements]
            visit_literal_elements(elements[1], inside_hash: true)
          end
        else
          skip_space_or_newline
        end

        write_softline
        check :on_rbrace
        write "}"
      end
      move_to_next_token
    end

    def visit_array(node)
      # [:array, elements]

      # Check if it's `%w(...)` or `%i(...)`
      case current_token_kind
      when :on_qwords_beg, :on_qsymbols_beg, :on_words_beg, :on_symbols_beg
        visit_q_or_i_array(node)
        return
      end

      _, elements = node

      check :on_lbracket
      write "["
      move_to_next_token

      if elements
        indent do
          visit_literal_elements to_ary(elements), inside_array: true
        end
      else
        skip_space_or_newline
      end

      check :on_rbracket
      write "]"

      move_to_next_token
    end

    def visit_class(node)
      # [:class,
      #   name
      #   superclass
      #   [:bodystmt, body, nil, nil, nil]]
      _, name, superclass, body = node

      consume_keyword "class"
      consume_space
      visit name

      if superclass
        skip_space_or_newline
        write " "
        consume_op "<"
        skip_space_or_newline
        write " "
        visit superclass
      end

      write_if_break(HARDLINE, "; ")
      visit body
    end

    def visit_module(node)
      # [:module,
      #   name
      #   [:bodystmt, body, nil, nil, nil]]
      _, name, body = node

      consume_keyword "module"
      consume_space
      skip_space_or_newline
      visit name

      write_if_break(HARDLINE, "; ")
      visit body
    end

    def visit_sclass(node)
      # class << self
      #
      # [:sclass, target, body]
      _, target, body = node

      consume_keyword "class"
      consume_space
      consume_op "<<"
      consume_space
      visit target
      write_if_break(HARDLINE, "; ")
      visit body
    end

    def visit_literal_elements(elements, inside_hash: false, inside_array: false)
      skip_space_or_newline
      write_line if inside_hash
      write_softline if inside_array

      elements.each_with_index do |elem, i|
        visit elem
        is_last = last?(i, elements)

        skip_space

        if comma?
          if is_last
            move_to_next_token
          else
            consume_token :on_comma
            skip_space_or_newline
            write_line
          end
        end

        if is_last
          if inside_hash
            write_if_break(",", " ")
          elsif inside_array
            write_if_break(",", "")
            skip_space_or_newline
            write_softline
          end
        end

        skip_space_or_newline
      end

      skip_space
    end

    def visit_hash_key_value(node)
      # key => value
      #
      # [:assoc_new, key, value]
      _, key, value = node

      # If a symbol comes it means it's something like
      # `:foo => 1` or `:"foo" => 1` and a `=>`
      # always follows
      symbol = current_token_kind == :on_symbeg
      arrow = symbol || !(key[0] == :@label || key[0] == :dyna_symbol)

      visit key
      consume_space

      # Don't output `=>` for keys that are `label: value`
      # or `"label": value`
      if arrow
        consume_op "=>"
        consume_space
      end

      visit value
    end

    def visit_splat_inside_hash(node)
      # **exp
      #
      # [:assoc_splat, exp]
      consume_op "**"
      skip_space_or_newline
      visit node[1]
    end

    def visit_control_keyword(node, keyword)
      _, exp = node

      consume_keyword keyword

      if exp && !exp.empty?
        consume_space if space?

        visit_exps to_ary(node[1]), with_lines: false
      end
    end

    def visit_quoted_symbol_literal(node)
      # :"foo"
      #
      # [:dyna_symbol, exps]
      _, exps = node

      # This is `"...":` as a hash key
      if current_token_kind == :on_tstring_beg
        consume_token :on_tstring_beg
        visit exps
        consume_token :on_label_end
      else
        consume_token :on_symbeg
        visit_exps exps, with_lines: false
        consume_token :on_tstring_end
      end
    end

    def visit_binary(node)
      # [:binary, left, op, right]
      _, left, op, right = node

      visit left

      consume_space unless op == :**

      consume_op_or_keyword op

      skip_space_or_newline

      indent do
        op == :** ? write_softline : write_line
        visit right
      end
    end

    def visit_unary(node)
      # [:unary, :-@, [:vcall, [:@ident, "x", [1, 2]]]]
      _, op, exp = node

      consume_op_or_keyword op

      if current_token_kind == :on_lparen
        consume_token :on_lparen
        skip_space_or_newline
        visit exp
        skip_space_or_newline
        consume_token :on_rparen
      else
        consume_space
        visit exp
      end
    end

    def visit_array_access(node)
      # exp[arg1, ..., argN]
      #
      # [:aref, name, args]
      _, name, args = node

      visit_array_getter_or_setter name, args
    end

    def visit_array_setter(node)
      # exp[arg1, ..., argN]
      # (followed by `=`, though not included in this node)
      #
      # [:aref_field, name, args]
      _, name, args = node

      visit_array_getter_or_setter name, args
    end

    def visit_array_getter_or_setter(name, args)
      visit name

      check :on_lbracket
      write "["
      move_to_next_token

      column = @column

      first_space = skip_space_or_newline

      group do
        # Sometimes args comes with an array...
        if args && args[0].is_a?(Array)
          visit_literal_elements args
        else
          if newline? || comment?
            if args
              write_softline
            else
              skip_space_or_newline
            end
          else
            write_softline
          end

          if args
            indent do
              visit args
            end
          end
        end

        write_if_break(",", "")
        write_softline
        skip_space_or_newline
        check :on_rbracket
        write "]"
      end

      move_to_next_token
    end

    def visit_call_args(node)
      # [:args_add_block, args, block]
      _, args, block_arg = node

      expression_context do
        if !args.empty? && args[0] == :args_add_star
          # arg1, ..., *star
          visit args
        else
          visit_comma_separated_list args
        end
      end
    end

    def visit_call_with_block(node)
      # [:method_add_block, call, block]
      _, call, block = node

      visit call

      consume_space

      old_dot_column = @dot_column
      old_original_dot_column = @original_dot_column

      group do
        visit block
      end

      @dot_column = old_dot_column
      @original_dot_column = old_original_dot_column
    end

    def visit_block(node)
      _, args, body = node

      group do
        write_if_break("do", "{")
        move_to_next_token

        consume_block_args args
        consume_space

        unless void_exps?(body)
          visit_exps(body, with_lines: false)
          consume_space
        end

        write_if_break("end", "}")
        move_to_next_token
      end
    end

    def visit_brace_block(node)
      # [:brace_block, args, body]
      visit_block(node)
    end

    def visit_do_block(node)
      # [:do_block, args, body]
      visit_block(node)
    end

    def visit_block_arguments(node)
      # [:block_var, params, local_params]
      _, params, local_params = node
      empty_params = empty_params?(params)

      check :on_op
      # check for ||
      if empty_params && !local_params
        # Don't write || as it's meaningless
        if current_token_value == "|"
          move_to_next_token
          skip_space_or_newline
          check :on_op
          move_to_next_token
        elsif current_token_value == "||"
          move_to_next_token
        else
          move_to_next_token
        end
        return
      end

      consume_token :on_op
      found_semicolon = skip_space_or_newline

      if found_semicolon
        # Nothing
      elsif empty_params && local_params
        consume_token :on_semicolon
        found_semicolon = true
      end

      skip_space_or_newline

      unless empty_params
        visit params
        skip_space
      end

      if local_params
        if semicolon?
          consume_token :on_semicolon
          consume_space
        end

        visit_comma_separated_list local_params
      else
        skip_space_or_newline
      end

      consume_op "|"
    end

    def visit_mlhs_paren(node)
      # [:mlhs_paren,
      #   [[:mlhs_paren, [:@ident, "x", [1, 12]]]]
      # ]
      _, args = node

      visit_mlhs_or_mlhs_paren(args)
    end

    def visit_mlhs_or_mlhs_paren(args)
      # Sometimes a paren comes, some times not, so act accordingly.
      has_paren = current_token_kind == :on_lparen
      if has_paren
        consume_token :on_lparen
        skip_space_or_newline
      end

      # For some reason there's nested :mlhs_paren for
      # a single parentheses. It seems when there's
      # a nested array we need parens, otherwise we
      # just output whatever's inside `args`.
      if args.is_a?(Array) && args[0].is_a?(Array)
        indent(@column) do
          visit_comma_separated_list args
          skip_space_or_newline
        end
      else
        visit args
      end

      if has_paren
        # Ripper has a bug where parsing `|(w, *x, y), z|`,
        # the "y" isn't returned. In this case we just consume
        # all tokens until we find a `)`.
        while current_token_kind != :on_rparen
          consume_token current_token_kind
        end

        consume_token :on_rparen
      end
    end

    def visit_command(node)
      # foo arg1, ..., argN
      #
      # [:command, name, args]
      _, name, args = node

      # base_column = current_token_column

      # push_call(node) do
        visit name
      #   consume_space_after_command_name
        consume_space
      # end

      visit_command_end(node, args)
    end

    def visit_command_end(node, args)
      # push_call(node) do
        visit_command_args(args)
      # end
    end

    def visit_command_args(args)
      needed_indent = @column
      args_is_def_class_or_module = false
      # param_column = current_token_column

      # Check if there's a single argument and it's
      # a def, class or module. In that case we don't
      # want to align the content to the position of
      # that keyword.
      if args[0] == :args_add_block
        nested_args = args[1]
        if nested_args.is_a?(Array) && nested_args.size == 1
          first = nested_args[0]
          if first.is_a?(Array)
            case first[0]
            when :def, :class, :module
              needed_indent = @indent
              args_is_def_class_or_module = true
            end
          end
        end
      end

      # base_line = @line
      # call_info = @line_to_call_info[@line]
      # if call_info
      #   call_info = nil
      # else
      #   call_info = [@indent, @column]
      #   @line_to_call_info[@line] = call_info
      # end

      old_want_first_token_in_line = @want_first_token_in_line
      @want_first_token_in_line = true

      # We align call parameters to the first paramter
      indent(needed_indent) do
        visit_exps to_ary(args), with_lines: false
      end

      # if call_info && call_info.size > 2
        # A call like:
        #
        #     foo, 1, [
        #       2,
        #     ]
        #
        # would normally be aligned like this (with the first parameter):
        #
        #     foo, 1, [
        #            2,
        #          ]
        #
        # However, the first style is valid too and we preserve it if it's
        # already formatted like that.
        # call_info << @line
      # elsif !args_is_def_class_or_module && @first_token_in_line && param_column == @first_token_in_line[0][1]
      if !args_is_def_class_or_module && @first_token_in_line && param_column == @first_token_in_line[0][1]
        # If the last line of the call is aligned with the first parameter, leave it like that:
        #
        #     foo 1,
        #         2
      elsif !args_is_def_class_or_module && @first_token_in_line && base_column + @indent_size == @first_token_in_line[0][1]
        # Otherwise, align it just by two spaces (so we need to dedent, we fake a dedent here)
        #
        #     foo 1,
        #       2
        @line_to_call_info[base_line] = [0, needed_indent - next_indent, true, @line, @line]
      end

      @want_first_token_in_line = old_want_first_token_in_line
    end

    def find_closing_brace_token
      count = 0
      i = @tokens.size - 1
      while i >= 0
        token = @tokens[i]
        (line, column), kind = token
        case kind
        when :on_lbrace, :on_tlambeg
          count += 1
        when :on_rbrace
          count -= 1
          return [token, i] if count == 0
        end
        i -= 1
      end
      nil
    end

    def to_ary(node)
      node[0].is_a?(Symbol) ? [node] : node
    end

    def indent_body(exps)
      indent do
        visit_exps exps #, with_lines: false
      end
    end

    def check(kind)
      if current_token_kind != kind
        bug "Expected token #{kind}, not #{current_token_kind}\n\n#{@tokens.last(4).reverse.ai}"
      end
    end

    def consume_token(kind)
      check kind
      consume_token_value(current_token_value)
      move_to_next_token
    end

    def consume_op(value)
      check :on_op
      if current_token_value != value
        bug "Expected op #{value}, not #{current_token_value}"
      end
      write value
      move_to_next_token
    end

    def consume_keyword(value)
      check :on_kw
      if current_token_value != value
        bug "Expected keyword #{value}, not #{current_token_value}"
      end
      write value
      move_to_next_token
    end

    def consume_op_or_keyword(op)
      case current_token_kind
      when :on_op, :on_kw
        write current_token_value
        move_to_next_token
      else
        bug "Expected op or kw, not #{current_token_kind}"
      end
    end

    def consume_space
      skip_space_or_newline
      write(" ")
    end

    def consume_block_args(args)
      if args
        empty_params?(args[1]) ? skip_space : consume_space
        group do
          indent(@column + 1) do
            visit args
          end
        end
      end
    end

    def void_exps?(node)
      node.size == 1 && node[0].size == 1 && node[0][0] == :void_stmt
    end

    def skip_space
      first_space = space? ? current_token : nil
      move_to_next_token while space?
      first_space
    end

    def skip_semicolons
      while semicolon? || space?
        move_to_next_token
      end
    end

    def space?
      current_token_kind == :on_sp
    end

    def semicolon?
      current_token_kind == :on_semicolon
    end

    def comma?
      current_token_kind == :on_comma
    end

    def last_is_newline?
      if @group
        @group.process
        @group.to_s[-1] == "\n"
      else
        @output[-1] == "\n"
      end
    end

    def last?(i, array)
      i == array.size - 1
    end

    def newline?
      current_token_kind == :on_nl || current_token_kind == :on_ignored_nl
    end

    def comment?
      current_token_kind == :on_comment
    end

    def keyword?(kw)
      current_token_kind == :on_kw && current_token_value == kw
    end

    def needs_two_lines?(exp)
      kind = exp[0]

      case kind
      when :def, :class, :module
        true
      else
        false
      end
    end

    def move_to_next_token
      @tokens.pop

      flush_heredocs if (newline? || comment?)
    end

    def flush_heredocs
      first_heredoc = true
      while heredoc = @heredocs.shift
        @current_heredoc = heredoc
        if first_heredoc
          write_hardline
          write_avoid_break
        end

        indent(0) do
          visit_string_literal_end(heredoc)
        end

        @current_heredoc = nil
        first_heredoc = false
      end
    end

    def next_token
      @tokens[-2]
    end

    def consume_token_value(value)
      write value
    end

    # [[1, 0], :on_int, "1"]
    def current_token
      @tokens.last
    end

    def token_kind(token)
      token ? token[1] : :on_eof
    end

    def current_token_kind
      token_kind(current_token)
    end

    def current_token_value
      token_value(current_token)
    end

    def token_value(token)
      token ? token[2] : ""
    end

    def current_token_line
      current_token[0][0]
    end

    def append(value)
      if @group
        @group << value
      else
        @output << value
      end
    end

    def write(value)
      append(value)
      value = Rufo::Group.string_value(value)

      if value == "\n"
        @last_was_newline = true
        @column = 0
      else
        @column += value.length
      end
    end

    def write_params_comma
      skip_space
      consume_token :on_comma
      move_to_next_token
      skip_space
      write_line
    end

    def write_breaking
      fail "Can only write BREAKING inside a group" unless @group

      @group.wants_break!
    end

    def write_avoid_break
      fail "Can only write avoid break inside a group" unless @group

      @group.avoid_break!
    end

    def write_line
      fail "Can only write LINE inside a group" unless @group

      write LINE
    end

    def write_softline
      fail "Can only write SOFTLINE inside a group" unless @group

      write SOFTLINE
    end

    def write_breaking_hardline
      if @group
        write HARDLINE
        write_breaking
      else
        write("\n")
      end
    end

    def write_hardline
      if @group
        write HARDLINE
      else
        write("\n")
      end
    end

    def write_if_break(break_value, no_break_value)
      fail "Can only write GroupIfBreak inside a group" unless @group

      write(GroupIfBreak.new(break_value, no_break_value))
    end

    def write_trailing(value)
      fail "Can only write GroupTrailing inside a group" unless @group

      write(GroupTrailing.new(value))
    end

    def write_group(group)
      if @group
        @group.concat([group])
      else
        group.process
        group.to_s.each_char { |c| write(c) }
        debug "write_group #{group.ai raw: true, index: false}"
      end
    end

    def set_indent(value)
      if @group
        append(GroupIndent.new(value))
      end

      @indent = value
    end

    def indent(value = nil)
      if value
        old_indent = @indent
        set_indent(value)
        yield
        set_indent(old_indent)
      else
        set_indent(@indent + @indent_size)
        yield
        set_indent(@indent - @indent_size)
      end
    end

    def dedent(value = nil)
      if value
        old_indent = @indent
        set_indent(value)
        yield
        set_indent(old_indent)
      else
        set_indent(@indent - @indent_size)
        yield
        set_indent(@indent + @indent_size)
      end
    end

    class ExpressionContext
      def initialize(dot_indent:)
        @chained_call_count = 0
        @dot_indent = dot_indent
      end

      attr_accessor :chained_call_count
      attr_reader :dot_indent
    end

    def expression_context
      old_expression_context = @expression_context
      @expression_context = ExpressionContext.new(dot_indent: @indent + @indent_size)
      yield
      @expression_context = old_expression_context
    end

    def group(name = nil)
      old_group = @group
      @group = Rufo::Group.new(name, indent: @indent, line_length: @line_length)
      name ||= @group.name
      debug "OPEN GROUP #{@group.object_id}"
      yield
      group_to_write = @group
      bug "tried to close a mismatched group (open: #{@group.name}, given: #{name})" unless @group.name == name
      @group = old_group
      debug "WRITE GROUP #{group_to_write.object_id}"
      write_group group_to_write
    end

    def consume_end
      return unless current_token_kind == :on___end__

      line = current_token_line

      write_breaking_hardline if @output[-2..-1] != "\n\n"
      consume_token :on___end__

      lines = @code.lines[line..-1]
      lines.each do |line|
        write line.chomp
        write_breaking_hardline
      end
    end

    def body_without_void_statements(body)
      body.reject { |e| e.first == :void_stmt }
    end

    def body_statement_empty?(body_statement)
      _, body, rescue_body, else_body, ensure_body = body_statement

      body_without_void_statements(body).empty? && !rescue_body && !else_body && !ensure_body
    end

    def body_statement_without_void_statements(body_statement)
      kind, *bodies = body_statement

      [
        kind,
        *bodies.map { |b| b && body_without_void_statements(b) },
      ]
    end

    def debug(msg)
      if DEBUG
        puts msg
      end
    end

    def bug(msg)
      raise Rufo::Bug.new("#{msg} at #{current_token}")
    end
  end
end
