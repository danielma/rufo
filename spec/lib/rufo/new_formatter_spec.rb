require "spec_helper"
require "fileutils"

NEW_FORMATTER_RUBY_VERSION = Gem::Version.new(RUBY_VERSION)
NEW_FORMATTER_FILE_PATH = Pathname.new(File.dirname(__FILE__))

def assert_source_specs(source_specs)
  relative_path = Pathname.new(source_specs).relative_path_from(NEW_FORMATTER_FILE_PATH).to_s

  describe relative_path do
    tests = []
    current_test = nil

    File.foreach(source_specs).with_index do |line, index|
      case
      when line =~ /^#~# ORIGINAL ?(skip ?)?(\:focus ?)?(.*)$/
        # save old test
        tests.push current_test if current_test

        # start a new test

        skip = !!$~[1]
        focus = !!$~[2]
        name = $~[3].strip
        name = "unnamed test" if name.empty?

        current_test = {name: name, line: index + 1, options: {}, original: "",skip: skip,focus: focus}
      when line =~ /^#~# EXPECTED$/
        current_test[:expected] = ""
      when line =~ /^#~# (.+)$/
        current_test[:options] = eval("{ #{$~[1]} }")
      when current_test[:expected]
        current_test[:expected] += line
      when current_test[:original]
        current_test[:original] += line
      end
    end

    (tests + [current_test]).each do |test|
      it "formats #{test[:name]} (line: #{test[:line]})", focus: test[:focus] do
        skip if test[:skip]
        error = nil

        begin
          formatted = described_class.format(test[:original], **test[:options]).to_s.strip
        rescue StandardError => e
          error = e
          formatted = ""
        end

        expected = test[:expected].strip

        if expected != formatted
          # message = "#{Rufi::Formatter.debug(test[:original], **test[:options])}\n\n" +
                    # "#{Rufi::Formatter.format(test[:original], **test[:options]).ai(index: false)}\n\n" +

          message = if test[:options].any?
                       "#~# OPTIONS\n\n" + test[:options].ai
                     else
                       ""
                     end

          message += "\n\n#~# ORIGINAL\n" +
                     test[:original] +
                     "#~# EXPECTED\n\n" +
                     expected +
                     "\n\n#~# ACTUAL\n\n" +
                     formatted +
                     "\n\n#~# INSPECT\n\n" +
                     formatted.inspect

          if error
            puts message
            fail error
          else
            fail message
          end
        end

        expect(formatted).to eq(expected)
      end
    end
  end
end

def assert_format(code, expected)
  it "formats #{code.inspect} to #{expected.inspect}" do
    expect(described_class.format(code)).to eq(expected)
  end
end

RSpec.describe Rufo::NewFormatter do
  %w(
    BEGIN
    END
    __END__
    alias
    align_assignments
    align_case_when
    align_chained_calls
    align_comments
    align_hash_keys
    align_mix
    array_access
    array_literal
    array_setter
    binary_operators
    hash_literal
    and_or_not
    assignment_operators
    assignments
    backtick_strings
    array_access
    rufi_basic
    rufi_classes
    rufi_strings
    comments
    booleans
    break
    next
    yield
    return
    calls_with_dot
    calls_with_receiver
    double_newline_inside_type
    case
    class
    class_into_self
    class_rescue_end
    class_variables
    constants
    defined?
    heredoc
    if
    indent_size
    integers
    junk_drawer
    method_argument_types
    property_setters
    begin_end
    lambdas
  ).each do |source_spec_name|
    file = File.join(NEW_FORMATTER_FILE_PATH, "/formatter_source_specs/#{source_spec_name}.rb.spec")
    fail "missing #{source_spec_name}" unless File.exist?(file)
    assert_source_specs(file) if File.file?(file)
  end

  # if NEW_FORMATTER_RUBY_VERSION >= Gem::Version.new("2.3")
  #   Dir[File.join(NEW_FORMATTER_FILE_PATH, "/source_specs/2.3/*")].each do |source_specs|
  #     assert_source_specs(source_specs) if File.file?(source_specs)
  #   end
  # end
end
