# frozen_string_literal: true

require "digest"

module Tailscope
  module CodeAnalyzer
    class << self
      def analyze_all(source_root: nil)
        source_root ||= Tailscope.configuration.source_root
        return [] unless source_root && Dir.exist?(source_root)

        issues = []
        issues.concat(analyze_models(source_root))
        issues.concat(analyze_controllers(source_root))
        issues.concat(analyze_all_ruby_files(source_root))
        issues
      end

      def analyze_file(file_path)
        file_path = File.expand_path(file_path)
        return [] unless File.exist?(file_path)
        return [] unless file_path.end_with?(".rb")

        content = File.read(file_path)
        lines = content.lines
        issues = []

        # Model-specific detectors
        if file_path.include?("/app/models/")
          issues.concat(detect_missing_validations(file_path, content, lines))
          issues.concat(detect_fat_model(file_path, content, lines))
          issues.concat(detect_callback_abuse(file_path, content, lines))
        end

        # Controller-specific detectors
        if file_path.include?("/app/controllers/")
          issues.concat(detect_missing_authentication(file_path, content, lines))
          issues.concat(detect_unsafe_params(file_path, content, lines))
          issues.concat(detect_data_exposure(file_path, content, lines))
          issues.concat(detect_direct_sql(file_path, content, lines))
          issues.concat(detect_fat_controller_actions(file_path, content, lines))
          issues.concat(detect_multiple_responsibilities(file_path, content, lines))
        end

        # General detectors (all Ruby files)
        issues.concat(detect_long_methods(file_path, lines))
        issues.concat(detect_long_class(file_path, lines))
        issues.concat(detect_todo_comments(file_path, lines))
        issues.concat(detect_hardcoded_secrets(file_path, lines))
        issues.concat(detect_empty_rescue(file_path, lines))
        issues.concat(detect_demeter_violations(file_path, lines))
        issues.concat(detect_complex_conditionals(file_path, lines))
        issues.concat(detect_deep_nesting(file_path, lines))
        issues.concat(detect_god_object(file_path, content, lines))
        issues.concat(detect_feature_envy(file_path, content, lines))
        issues.concat(detect_boolean_parameters(file_path, lines))
        issues.concat(detect_large_parameter_list(file_path, lines))
        issues.concat(detect_primitive_obsession(file_path, content, lines))
        issues.concat(detect_explanatory_comments(file_path, lines))

        issues
      end

      private

      def analyze_models(root)
        issues = []
        Dir.glob(File.join(root, "app", "models", "**", "*.rb")).each do |file|
          content = File.read(file)
          lines = content.lines
          issues.concat(detect_missing_validations(file, content, lines))
          issues.concat(detect_fat_model(file, content, lines))
          issues.concat(detect_callback_abuse(file, content, lines))
        end
        issues
      end

      def analyze_controllers(root)
        issues = []
        Dir.glob(File.join(root, "app", "controllers", "**", "*.rb")).each do |file|
          content = File.read(file)
          lines = content.lines
          issues.concat(detect_missing_authentication(file, content, lines))
          issues.concat(detect_unsafe_params(file, content, lines))
          issues.concat(detect_data_exposure(file, content, lines))
          issues.concat(detect_direct_sql(file, content, lines))
          issues.concat(detect_fat_controller_actions(file, content, lines))
          issues.concat(detect_multiple_responsibilities(file, content, lines))
        end
        issues
      end

      def analyze_all_ruby_files(root)
        issues = []
        Dir.glob(File.join(root, "app", "**", "*.rb")).each do |file|
          content = File.read(file)
          lines = content.lines
          issues.concat(detect_long_methods(file, lines))
          issues.concat(detect_long_class(file, lines))
          issues.concat(detect_todo_comments(file, lines))
          issues.concat(detect_hardcoded_secrets(file, lines))
          issues.concat(detect_empty_rescue(file, lines))
          issues.concat(detect_demeter_violations(file, lines))
          issues.concat(detect_complex_conditionals(file, lines))
          issues.concat(detect_deep_nesting(file, lines))
          issues.concat(detect_god_object(file, content, lines))
          issues.concat(detect_feature_envy(file, content, lines))
          issues.concat(detect_boolean_parameters(file, lines))
          issues.concat(detect_large_parameter_list(file, lines))
          issues.concat(detect_primitive_obsession(file, content, lines))
          issues.concat(detect_explanatory_comments(file, lines))
        end
        issues
      end

      # --- Model Detectors ---

      def detect_missing_validations(file, content, _lines)
        return [] unless content =~ /class\s+(\w+)\s*<\s*ApplicationRecord/

        model_name = $1
        return [] if content =~ /\b(validates|validate|has_secure_password)\b/

        # Try to find belongs_to associations to suggest specific validations
        associations = content.scan(/belongs_to\s+:(\w+)/).flatten
        columns = content.scan(/has_many\s+:(\w+)/).flatten

        fix = "Add validations to `#{model_name}`. For example:\n"
        fix += "`validates :name, presence: true`\n" if associations.empty?
        associations.each do |assoc|
          fix += "`validates :#{assoc}, presence: true`\n"
        end
        fix += "Check your schema for columns that should never be blank and add `presence: true` for each."

        [build_issue(
          severity: :warning,
          title: "Missing Validations — #{model_name}",
          description: "#{model_name} model has no validations. Data can be saved in an invalid state.",
          source_file: file,
          source_line: find_class_line(content),
          suggested_fix: fix,
        )]
      end

      # --- Controller Detectors ---

      def detect_missing_authentication(file, content, _lines)
        return [] unless content =~ /class\s+([\w:]+Controller)\s*</
        controller_name = $1
        return [] if controller_name == "ApplicationController"
        return [] if content =~ /before_action\s+.*(?:authenticate|authorize|require_login|require_admin|ensure_authenticated)/

        [build_issue(
          severity: :warning,
          title: "Missing Authentication — #{controller_name}",
          description: "#{controller_name} has no authentication before_action. All actions are publicly accessible.",
          source_file: file,
          source_line: find_class_line(content),
          suggested_fix: "Add at the top of `#{controller_name}`:\n`before_action :authenticate_user!`\nOr if using a custom auth system:\n`before_action :require_login`",
        )]
      end

      def detect_unsafe_params(file, content, lines)
        return [] unless content =~ /class\s+([\w:]+Controller)/
        controller_name = $1

        issues = []
        lines.each_with_index do |line, idx|
          next if line =~ /^\s*#/
          next unless line =~ /params\[:\w+\]|params\.dig\(/
          next if line =~ /\.permit\b/
          next if line =~ /\bparams\[:page\]|\bparams\[:id\]|\bparams\[:format\]/
          next if content =~ /def\s+\w+_params.*\.permit/m

          # Extract the param name for a specific fix
          param_name = line[/params\[:(\w+)\]/, 1] || line[/params\.dig\(:(\w+)/, 1] || "resource"

          issues << build_issue(
            severity: :warning,
            title: "Unsafe Params Access",
            description: "Direct `params` access without strong parameters. User input is not filtered, risking mass assignment.",
            source_file: file,
            source_line: idx + 1,
            suggested_fix: "Replace direct `params` access with strong parameters.\nAdd a private method to `#{controller_name}`:\n`def #{param_name}_params`\n`  params.require(:#{param_name}).permit(:field1, :field2)`\n`end`",
          )
        end
        issues
      end

      def detect_data_exposure(file, content, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line =~ /^\s*#/
          next unless line =~ /render\s+json:\s+(@\w+)/
          var_name = $1
          next if line =~ /\b(only|except|serializer|as_json|to_json)\b/

          issues << build_issue(
            severity: :critical,
            title: "Data Exposure — JSON Response",
            description: "Rendering `#{var_name}` as JSON exposes all database columns, including potentially sensitive fields (email, api_key, password_digest).",
            source_file: file,
            source_line: idx + 1,
            suggested_fix: "Before:\n`render json: #{var_name}`\nAfter — whitelist safe fields:\n`render json: #{var_name}.as_json(only: [:id, :name])`\nOr create a serializer to control the JSON shape.",
          )
        end
        issues
      end

      def detect_direct_sql(file, _content, lines)
        issues = []
        patterns = [
          [/Arel\.sql\(/, "Arel.sql usage"],
          [/find_by_sql\(/, "find_by_sql usage"],
          [/\.order\(\s*["'].*(?:RANDOM|RAND|LENGTH)\b/i, "SQL function in order clause"],
          [/\.where\(\s*["'][^"']*(?:SELECT|INSERT|UPDATE|DELETE)\b/i, "Raw SQL in where clause"],
        ]

        lines.each_with_index do |line, idx|
          next if line =~ /^\s*#/
          patterns.each do |pattern, label|
            next unless line =~ pattern

            snippet = line.strip.length > 60 ? line.strip[0..60] + "..." : line.strip
            fix = case label
                  when "Arel.sql usage"
                    "Replace `Arel.sql(...)` with ActiveRecord methods.\nBefore: `.order(Arel.sql(\"LENGTH(name) DESC\"))`\nAfter: `.order(name: :desc)` or use Arel nodes:\n`.order(Model.arel_table[:name].length.desc)`"
                  when "SQL function in order clause"
                    "Replace raw SQL ordering with ActiveRecord.\nBefore: `.order(\"RANDOM()\")`\nAfter: `.order(Arel.sql(\"RANDOM()\"))` (explicit) or refactor to avoid DB-specific functions."
                  when "find_by_sql usage"
                    "Replace `find_by_sql` with ActiveRecord query methods like `.where`, `.joins`, `.select` which are safer and more portable."
                  else
                    "Replace raw SQL string with ActiveRecord query methods.\n`.where(column: value)` instead of `.where(\"column = ?\", value)`"
                  end

            issues << build_issue(
              severity: :warning,
              title: "Direct SQL — #{label}",
              description: "Raw SQL on this line: `#{snippet}`",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: fix,
            )
          end
        end
        issues
      end

      # --- SOLID / Architecture Detectors ---

      def detect_fat_controller_actions(file, content, lines)
        return [] unless content =~ /class\s+([\w:]+Controller)\s*</
        controller_name = $1
        return [] if controller_name == "ApplicationController"

        issues = []
        methods = extract_methods(lines)

        methods.each do |m|
          total_lines = m[:end_line] - m[:start_line] - 1
          if total_lines > 15
                service_name = controller_name.sub("Controller", "") + m[:name].capitalize + "Service"
                issues << build_issue(
                  severity: :warning,
                  title: "Fat Controller Action — #{controller_name}##{m[:name]}",
                  description: "`#{m[:name]}` has #{total_lines} lines. Controllers should only handle request/response flow.",
                  source_file: file,
                  source_line: m[:start_line] + 1,
                  suggested_fix: "Move business logic out of the action into a service object.\nCreate `app/services/#{service_name.gsub('::', '/').underscore}.rb`:\n`class #{service_name}`\n`  def call`\n`    # move logic here`\n`  end`\n`end`\nThen in the controller:\n`def #{m[:name]}`\n`  @result = #{service_name}.new.call`\n`end`",
                )
              end
        end
        issues
      end

      def detect_multiple_responsibilities(file, content, lines)
        return [] unless content =~ /class\s+([\w:]+Controller)\s*</
        controller_name = $1
        return [] if controller_name == "ApplicationController"

        # Count distinct model classes referenced
        model_refs = Set.new
        lines.each do |line|
          next if line.strip.start_with?("#")
          line.scan(/\b([A-Z][a-z]\w+)\.(find|where|count|all|joins|includes|create|new|order|group|select|left_joins|pluck)\b/) do |match|
            model_refs.add(match[0])
          end
        end

        if model_refs.size >= 3
          [build_issue(
            severity: :warning,
            title: "Multiple Responsibilities — #{controller_name}",
            description: "#{controller_name} directly queries #{model_refs.size} different models (#{model_refs.to_a.join(', ')}). This suggests the controller is handling too many concerns (SRP violation).",
            source_file: file,
            source_line: find_class_line(content),
            suggested_fix: "This controller queries #{model_refs.to_a.join(', ')} directly.\nExtract into a query object or presenter:\n`class #{controller_name.sub('Controller', '')}Dashboard`\n`  def initialize`\n#{model_refs.first(3).map { |m| "`    @#{m.downcase.gsub('::', '_')}s = #{m}.all`" }.join("\n")}\n`  end`\n`end`\nThen in the controller: `@dashboard = #{controller_name.sub('Controller', '')}Dashboard.new`",
          )]
        else
          []
        end
      end

      def detect_fat_model(file, content, lines)
        return [] unless content =~ /class\s+(\w+)\s*<\s*ApplicationRecord/
        model_name = $1

        # Check for mixed concerns: callbacks + business logic + presentation + external calls
        concerns = []
        concerns << "callbacks" if content =~ /\b(before_|after_|around_)(save|create|update|destroy|validation|commit)\b/
        concerns << "presentation logic" if content =~ /\bdef\s+(display_|full_|format_|to_csv|to_pdf)\w*/
        concerns << "query logic" if content =~ /\bscope\s+:/ || (content.scan(/\bdef\s+self\.\w+/).length >= 3)
        concerns << "external service calls" if content =~ /(Mailer|deliver_|HTTParty|Faraday|RestClient|sync_to_|track_|notify_)/

        if concerns.size >= 3
          [build_issue(
            severity: :warning,
            title: "Fat Model — #{model_name}",
            description: "#{model_name} mixes #{concerns.join(', ')}. Models with too many responsibilities are harder to test and maintain (SRP violation).",
            source_file: file,
            source_line: find_class_line(content),
            suggested_fix: "#{model_name} mixes #{concerns.join(' + ')}. Split into focused pieces:\n#{concerns.include?('presentation logic') ? "Move display/format methods → `app/presenters/#{model_name.underscore}_presenter.rb`\n" : ''}#{concerns.include?('callbacks') ? "Move side-effect callbacks → `app/services/#{model_name.underscore}_lifecycle.rb`\n" : ''}#{concerns.include?('external service calls') ? "Move API/mailer calls → `app/services/#{model_name.underscore}_notifier.rb`\n" : ''}#{concerns.include?('query logic') ? "Move scopes/class methods → `app/models/concerns/#{model_name.underscore}_queries.rb`\n" : ''}Keep only validations, associations, and core data logic in the model.",
          )]
        else
          []
        end
      end

      def detect_callback_abuse(file, content, lines)
        return [] unless content =~ /class\s+(\w+)\s*<\s*ApplicationRecord/
        model_name = $1

        callback_lines = []
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")
          if line =~ /\b(before_|after_|around_)(save|create|update|destroy|validation|commit)\b/
            callback_lines << idx + 1
          end
        end

        if callback_lines.size >= 4
          [build_issue(
            severity: :warning,
            title: "Callback Abuse — #{model_name}",
            description: "#{model_name} has #{callback_lines.size} callbacks. Excessive callbacks create hidden control flow, make debugging difficult, and violate the Single Responsibility Principle.",
            source_file: file,
            source_line: callback_lines.first,
            suggested_fix: "#{model_name} has #{callback_lines.size} callbacks — these create hidden control flow.\nBefore: callbacks trigger side effects implicitly on save\nAfter: call services explicitly from the controller\n`class #{model_name}Service`\n`  def create(params)`\n`    #{model_name}.create!(params).tap do |record|`\n`      send_notification(record)`\n`      sync_to_external(record)`\n`    end`\n`  end`\n`end`\nKeep only data-normalizing callbacks (e.g. `before_validation :strip_whitespace`) in the model.",
          )]
        else
          []
        end
      end

      # --- SOLID & Readability Detectors ---

      def detect_complex_conditionals(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")
          stripped = line.strip

          # Detect complex boolean expressions with multiple conditions
          and_or_count = stripped.scan(/\s+(and|or|\&\&|\|\|)\s+/).size
          if and_or_count >= 3
            issues << build_issue(
              severity: :warning,
              title: "Complex Conditional Logic",
              description: "This line has #{and_or_count + 1} conditions joined with AND/OR. Complex conditionals are hard to read and test.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Before:\n`if #{stripped.length > 70 ? stripped[0..70] + '...' : stripped}`\nAfter — extract to a well-named predicate method:\n`def ready_to_process?`\n`  condition_1 && condition_2 && condition_3`\n`end`\nThen: `if ready_to_process?`\nOr use early returns:\n`return unless condition_1`\n`return unless condition_2`\n`# proceed with logic`",
            )
          end

          # Detect long elsif chains (code smell, violates OCP)
          if stripped =~ /^\s*elsif\b/
            # Count how many elsifs we have
            elsif_count = lines[(idx - 5).clamp(0, lines.size)..(idx + 10).clamp(0, lines.size)].count { |l| l.strip.start_with?("elsif") }
            if elsif_count >= 3
              issues << build_issue(
                severity: :warning,
                title: "Long If/Elsif Chain",
                description: "Found #{elsif_count} elsif statements. Long if/elsif chains violate the Open/Closed Principle and are hard to maintain.",
                source_file: file,
                source_line: idx + 1,
                suggested_fix: "Before:\n`if type == :a`\n`  ...`\n`elsif type == :b`\n`  ...`\n`elsif type == :c`\n`  ...`\nAfter — use a hash or polymorphism:\nOption 1 (Hash):\n`HANDLERS = { a: -> { ... }, b: -> { ... }, c: -> { ... } }`\n`HANDLERS[type]&.call`\nOption 2 (Polymorphism):\nCreate separate classes for each type and use:\n`handler_class = \"#{type.capitalize}Handler\".constantize`\n`handler_class.new.handle`",
              )
              break # Only report once per chain
            end
          end
        end
        issues
      end

      def detect_deep_nesting(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line.strip.empty? || line.strip.start_with?("#")

          # Calculate indentation level (spaces / 2)
          indent = line[/^\s*/].length / 2

          # Flag lines with 4+ levels of nesting (8+ spaces)
          if indent >= 4
            issues << build_issue(
              severity: :warning,
              title: "Deep Nesting",
              description: "Code is nested #{indent} levels deep. Deep nesting makes code hard to follow and increases cognitive load.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Deep nesting (#{indent} levels) makes code hard to read.\nRefactor using:\n1. **Guard clauses** (early returns):\n`return unless condition`\n`return if invalid?`\n`# main logic at top level`\n2. **Extract methods**:\nMove nested blocks into well-named private methods\n3. **Invert conditions**:\n`next unless item.valid?` instead of `if item.valid?`\nAim for max 2-3 levels of nesting.",
            )
          end
        end
        issues
      end

      def detect_god_object(file, content, lines)
        return [] unless content =~ /class\s+(\w+)/
        class_name = $1

        # Count dependencies: instance variable assignments, constants, and injected classes
        dependencies = Set.new

        # Count instance variables being set
        content.scan(/@(\w+)\s*=/).each { |match| dependencies.add("@#{match[0]}") }

        # Count collaborator classes (method calls on capitalized constants)
        content.scan(/\b([A-Z][a-z]\w+)\.(new|find|where|create|call|perform|deliver|fetch|get|post|send)/).each do |match|
          dependencies.add(match[0]) unless match[0] == class_name
        end

        if dependencies.size >= 7
          issues = [build_issue(
            severity: :warning,
            title: "God Object — #{class_name}",
            description: "#{class_name} has #{dependencies.size} dependencies (#{dependencies.to_a[0..5].join(', ')}...). Classes with many dependencies are hard to test and violate SRP.",
            source_file: file,
            source_line: find_class_line(content),
            suggested_fix: "#{class_name} depends on #{dependencies.size} things. This is a **God Object** anti-pattern.\nRefactor by:\n1. **Group related dependencies** — what naturally belongs together?\n2. **Extract collaborators** into separate service objects:\n`class #{class_name}Notifications`\n`  def initialize(#{class_name.underscore})`\n`    @#{class_name.underscore} = #{class_name.underscore}`\n`  end`\n`  # Move notification logic here`\n`end`\n3. **Inject only what's needed** for each method\n4. **Use dependency injection** instead of hard-coded dependencies\nAim for 5 or fewer dependencies per class.",
          )]
        else
          []
        end
      end

      def detect_feature_envy(file, content, lines)
        return [] unless content =~ /class\s+(\w+)/
        class_name = $1

        issues = []
        methods = extract_methods(lines)

        methods.each do |m|
          method_lines = lines[(m[:start_line] + 1)..(m[:end_line] - 1)] || []
          next if method_lines.size < 3

          # Count references to other objects vs self
          external_calls = 0
          self_calls = 0

          method_lines.each do |line|
            # Count calls to other objects (instance variables, parameters)
            external_calls += line.scan(/(\w+)\.\w+/).size
            # Count self calls (implicit or explicit)
            self_calls += 1 if line =~ /(@\w+|self\.|\bsend\(|\bpublic_send\()/
          end

          # If more than 70% of calls are to other objects, it's feature envy
          total_calls = external_calls + self_calls
          next if total_calls < 4

          if external_calls.to_f / total_calls > 0.7
            issues << build_issue(
              severity: :info,
              title: "Feature Envy — #{m[:name]}",
              description: "Method `#{m[:name]}` in #{class_name} makes #{external_calls} calls to other objects but only #{self_calls} to self. It's using more data from another class than its own (Feature Envy).",
              source_file: file,
              source_line: m[:start_line] + 1,
              suggested_fix: "`#{m[:name]}` uses more data from other objects than from `#{class_name}`.\nThis suggests it belongs in another class (Feature Envy).\nBefore:\n`class #{class_name}`\n`  def #{m[:name]}`\n`    other_object.data1 + other_object.data2`\n`  end`\n`end`\nAfter — move to where the data lives:\n`class OtherClass`\n`  def #{m[:name]}`\n`    data1 + data2`\n`  end`\n`end`\nData and behavior that change together should live together.",
            )
          end
        end
        issues
      end

      def detect_boolean_parameters(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")
          # Detect method definitions with boolean-looking parameters
          if line =~ /def\s+\w+.*\((.*)\)/
            params = $1
            # Check for parameters with is_, has_, should_, or boolean default values
            if params =~ /\b(is_\w+|has_\w+|should_\w+|enabled|disabled|flag|active)/i || params =~ /=\s*(true|false)\b/
              issues << build_issue(
                severity: :info,
                title: "Boolean Parameter (Flag Argument)",
                description: "Method has a boolean parameter. Boolean flags make methods do more than one thing and violate SRP.",
                source_file: file,
                source_line: idx + 1,
                suggested_fix: "Boolean parameters are a code smell (flag arguments).\nBefore:\n`def send_message(user, is_urgent: false)`\n`  if is_urgent`\n`    # urgent path`\n`  else`\n`    # normal path`\n`  end`\n`end`\nAfter — split into two methods:\n`def send_message(user)`\n`  # normal message`\n`end`\n`def send_urgent_message(user)`\n`  # urgent message`\n`end`\nMethods should do one thing. Use polymorphism or separate methods instead of flags.",
              )
            end
          end
        end
        issues
      end

      def detect_large_parameter_list(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")

          if line =~ /def\s+(\w+[\?\!]?)\((.*?)\)/ || line =~ /def\s+(\w+[\?\!]?)\s*$/
            method_name = $1
            params = $2 || ""

            # Count parameters (split by comma, but not inside nested parens/brackets)
            param_count = params.split(",").size
            param_count = 0 if params.strip.empty?

            if param_count >= 4
              issues << build_issue(
                severity: :warning,
                title: "Long Parameter List — #{method_name}",
                description: "`#{method_name}` has #{param_count} parameters. Long parameter lists are hard to remember and indicate the method may be doing too much.",
                source_file: file,
                source_line: idx + 1,
                suggested_fix: "`#{method_name}` has #{param_count} parameters — too many to remember.\nRefactor by:\n1. **Introduce Parameter Object**:\n`class #{method_name.camelize}Params`\n`  attr_accessor :param1, :param2, :param3`\n`  def initialize(param1:, param2:, param3:)`\n`    @param1, @param2, @param3 = param1, param2, param3`\n`  end`\n`end`\nThen: `def #{method_name}(params)`\n2. **Use keyword arguments** if not already\n3. **Split the method** if it's doing too much\nAim for 3 or fewer parameters.",
              )
            end
          end
        end
        issues
      end

      def detect_primitive_obsession(file, content, lines)
        return [] unless content =~ /class\s+(\w+)/
        class_name = $1

        issues = []

        # Look for methods returning or accepting raw hashes that could be objects
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")

          # Detect methods building large hash literals
          if line =~ /\{.*:.*=>.*:.*=>.*:.*=>/ || line.count(":") >= 4 && line.include?("=>")
            issues << build_issue(
              severity: :info,
              title: "Primitive Obsession — Large Hash",
              description: "Large hash literal detected. Using primitives (hashes, arrays, strings) instead of small objects makes code less expressive (Primitive Obsession).",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Before:\n`{ name: ..., email: ..., role: ..., status: ... }`\nAfter — create a small value object:\n`class UserAttributes`\n`  attr_reader :name, :email, :role, :status`\n`  def initialize(name:, email:, role:, status:)`\n`    @name, @email, @role, @status = name, email, role, status`\n`  end`\n`  def admin? = role == 'admin'`\n`end`\nSmall objects make code more expressive and testable.",
            )
          end

          # Detect phone/email/zip patterns being validated with regex (should be value objects)
          if line =~ /=~.*\/.*(@|phone|zip|ssn|credit|card)/i
            issues << build_issue(
              severity: :info,
              title: "Primitive Obsession — String Validation",
              description: "String validation pattern detected. Domain concepts like emails, phones should be value objects, not primitives.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Before:\n`email =~ /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i`\nAfter — create a value object:\n`class Email`\n`  def initialize(value)`\n`    @value = value`\n`    validate!`\n`  end`\n`  def valid? = @value =~ PATTERN`\n`  private`\n`  def validate!`\n`    raise ArgumentError unless valid?`\n`  end`\n`end`\nThen: `email = Email.new(input)`\nValue objects encapsulate validation and domain logic.",
            )
          end
        end

        issues
      end

      def detect_explanatory_comments(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next unless line.strip.start_with?("#")
          comment = line.strip[1..-1]&.strip || ""
          next if comment.empty?
          next if comment.start_with?("TODO", "FIXME", "HACK", "NOTE", "WARNING")
          next if comment.length < 20 # Skip short comments

          # Look for comments that explain what code does (not why)
          # Check if next non-comment line exists
          next_line_idx = (idx + 1...lines.size).find { |i| !lines[i].strip.empty? && !lines[i].strip.start_with?("#") }
          next unless next_line_idx

          next_line = lines[next_line_idx].strip

          # Skip if comment is about "why" (contains because, due to, workaround, etc.)
          next if comment =~ /\b(because|due to|workaround|hack|bug|reason|for|to avoid|rails\s+\d|ruby\s+\d)\b/i

          # Flag if comment describes what the code does
          # This is a heuristic: comment mentions methods or variables in the next line
          code_words = next_line.scan(/\w{3,}/).to_set
          comment_words = comment.scan(/\w{3,}/).to_set
          overlap = code_words & comment_words

          if overlap.size >= 2
            issues << build_issue(
              severity: :info,
              title: "Explanatory Comment",
              description: "Comment explains *what* the code does. Code should be self-documenting through naming. Comments should explain *why*.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "This comment explains what the code does — the code should explain itself.\nBefore:\n`# #{comment.length > 50 ? comment[0..50] + '...' : comment}`\n`#{next_line.length > 50 ? next_line[0..50] + '...' : next_line}`\nAfter — make code self-documenting:\n1. **Extract to a well-named method** that describes what it does\n2. **Use better variable names** that explain purpose\n3. Reserve comments for *why*, not *what*:\n`# Workaround for Rails 6 bug #12345`\n`# Performance: batch to avoid N+1`\nGood code reads like prose.",
            )
          end
        end
        issues
      end

      def detect_demeter_violations(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line.strip.start_with?("#")

          # Match chains of 4+ method calls (not 3, as association.scope.method is fine in Rails)
          # e.g., user.posts.published.comments.count is a violation
          if line =~ /\b\w+(?:[&.]\.?\w+){4,}/
            chain = line.strip[/(\w+(?:\&?\.\w+){4,})/, 1]
            next unless chain
            dots = chain.count(".")
            next if dots < 4

            # Skip Rails query chains (association + scope + query methods)
            next if chain =~ /\.(where|select|order|group|joins|includes|left_joins|eager_load|preload|references|limit|offset|distinct|uniq|having|lock|readonly|from|reorder|reverse_order|rewhere|create_with|none|any|many|one|first|last|find|find_by|take|exists|count|sum|average|minimum|maximum|calculate|pluck|pick|ids|map|each|collect|reject|find_all|filter|select)\b/

            # Skip common Rails patterns
            next if chain.start_with?("Rails.")
            next if chain.start_with?("ActiveRecord.")
            next if chain.start_with?("ActiveSupport.")
            next if chain =~ /\.to_[a-z]+\./
            next if chain =~ /\.errors\.(full_)?messages/

            # Skip configurations and constants
            next if chain =~ /[A-Z_]{2,}/

            # Skip test/spec helper chains
            next if chain =~ /(expect|should|mock|stub|double|spy)\b/

            issues << build_issue(
              severity: :info,
              title: "Law of Demeter Violation",
              description: "Long method chain `#{chain.length > 60 ? chain[0..60] + '...' : chain}` crosses multiple object boundaries. This creates tight coupling.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Before:\n`#{chain.length > 50 ? chain[0..50] + '...' : chain}`\nAfter — add a delegate method:\n`delegate :#{chain.split('.').last}, to: :#{chain.split('.')[1]}, prefix: true`\nOr wrap in a method:\n`def #{chain.split('.').last}_value`\n`  #{chain.split('.')[0..1].join('.')}&.#{chain.split('.')[2..]&.join('.')}`\n`end`\nEach object should only talk to its immediate neighbors.",
            )
          end
        end
        issues
      end

      # --- General Detectors ---

      def detect_long_class(file, lines)
        class_name = nil
        class_line = nil
        lines.each_with_index do |line, idx|
          if line =~ /^\s*class\s+(\S+)/
            class_name = $1
            class_line = idx + 1
            break
          end
        end
        return [] unless class_name

        non_blank = lines.count { |l| l.strip.length > 0 && !l.strip.start_with?("#") }
        threshold = file.include?("/models/") ? 80 : 120

        if non_blank > threshold
          category = file.include?("/models/") ? "Model" : file.include?("/controllers/") ? "Controller" : "Class"
          [build_issue(
            severity: :warning,
            title: "Long #{category} — #{class_name}",
            description: "#{class_name} has #{non_blank} non-blank lines (threshold: #{threshold}). Large classes are harder to understand, test, and maintain.",
            source_file: file,
            source_line: class_line,
            suggested_fix: "#{class_name} is #{non_blank} lines (limit: #{threshold}).\nExtract groups of related methods into:\n`app/models/concerns/#{class_name.underscore}_searchable.rb` — search/scope methods\n`app/services/#{class_name.underscore}_service.rb` — business logic\n`app/presenters/#{class_name.underscore}_presenter.rb` — display helpers\nIn the model: `include #{class_name}Searchable`\nAim for classes under #{threshold} lines with a single clear purpose.",
          )]
        else
          []
        end
      end

      def detect_long_methods(file, lines)
        issues = []
        methods = extract_methods(lines)

        methods.each do |m|
          body = lines[(m[:start_line] + 1)..(m[:end_line] - 1)] || []
          non_blank = body.count { |l| l.strip.length > 0 }
          if non_blank > 20
            issues << build_issue(
              severity: :info,
              title: "Long Method — #{m[:name]}",
              description: "Method `#{m[:name]}` is #{non_blank} lines long. Long methods are harder to understand and test.",
              source_file: file,
              source_line: m[:start_line] + 1,
              suggested_fix: "`#{m[:name]}` is #{non_blank} lines (limit: 20).\nBreak it into smaller methods with descriptive names:\n`def #{m[:name]}`\n`  validate_input`\n`  process_data`\n`  build_response`\n`end`\nEach extracted method should do one thing. Name it after what it does, not how.",
            )
          end
        end
        issues
      end

      def detect_todo_comments(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          if line =~ /#\s*(TODO|FIXME|HACK)\b[:\s]*(.*)/
            tag = $1
            message = $2.strip
            issues << build_issue(
              severity: :info,
              title: "#{tag} Comment",
              description: message.empty? ? "#{tag} comment found — indicates unfinished or problematic code." : "#{tag}: #{message}",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "This `#{tag}` has been in the codebase — don't let it become permanent.\nEither fix it now and remove the comment, or create a ticket to track it.\nIf the work is non-trivial, replace with:\n`# #{tag}: [JIRA-123] Brief description`\nso it's traceable.",
            )
          end
        end
        issues
      end

      def detect_hardcoded_secrets(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next if line =~ /^\s*#/
          next unless line =~ /\b\w*(SECRET|PASSWORD|API_KEY|TOKEN|PRIVATE_KEY)\w*\s*=\s*["'][^"']+["']/i
          next if line =~ /ENV\[|Rails\.application\.credentials|ENV\.fetch/

          issues << build_issue(
            severity: :critical,
            title: "Hardcoded Secret",
            description: "A secret value appears to be hardcoded in source code. This is a security risk if the code is committed to version control.",
            source_file: file,
            source_line: idx + 1,
            suggested_fix: "Before:\n`API_KEY = \"sk_live_abc123...\"`\nAfter — use environment variables:\n`API_KEY = ENV.fetch(\"API_KEY\")`\nOr Rails credentials:\n`API_KEY = Rails.application.credentials.api_key`\nThen set the value in `.env` (development) or your hosting platform's secrets manager (production).\nNever commit secrets to version control.",
          )
        end
        issues
      end

      def detect_empty_rescue(file, lines)
        issues = []
        lines.each_with_index do |line, idx|
          next unless line =~ /^\s*rescue\b/

          next_meaningful = nil
          (idx + 1...[idx + 6, lines.length].min).each do |j|
            stripped = lines[j]&.strip
            next if stripped.nil? || stripped.empty? || stripped.start_with?("#")
            next_meaningful = stripped
            break
          end

          if next_meaningful == "end" || next_meaningful.nil?
            issues << build_issue(
              severity: :warning,
              title: "Empty Rescue Block",
              description: "Exception is rescued but silently swallowed. This hides bugs and makes debugging difficult.",
              source_file: file,
              source_line: idx + 1,
              suggested_fix: "Before:\n`rescue`\n`end`\nAfter — at minimum, log the error:\n`rescue => e`\n`  Rails.logger.error(\"[ClassName] Failed: \#\{e.message\}\")`\n`end`\nOr re-raise if the caller should handle it:\n`rescue => e`\n`  Rails.logger.error(e.message)`\n`  raise`\n`end`\nSilently swallowing exceptions hides bugs.",
            )
          end
        end
        issues
      end

      # --- Helpers ---

      def build_issue(severity:, title:, description:, source_file:, source_line:, suggested_fix:)
        Issue.new(
          severity: severity,
          type: :code_smell,
          title: title,
          description: description,
          source_file: source_file,
          source_line: source_line,
          suggested_fix: suggested_fix,
          occurrences: 1,
          total_duration_ms: nil,
          latest_at: nil,
          raw_ids: [],
          raw_type: "code_smell",
          metadata: {},
          fingerprint: Digest::SHA256.hexdigest("code_smell|#{title}|#{source_file}|#{source_line}")[0, 16],
        )
      end

      # Extract method boundaries accounting for all Ruby keywords (if/do/begin/etc.)
      def extract_methods(lines)
        methods = []
        method_start = nil
        method_name = nil
        keyword_depth = 0

        lines.each_with_index do |line, idx|
          stripped = line.strip
          next if stripped.start_with?("#")
          next if stripped.empty?

          # Count opening keywords
          opens = stripped.scan(/\b(def|class|module|if|unless|case|while|until|for|begin|do)\b/).size
          # Postfix if/unless/while/until on single-expression lines don't open blocks
          # Only subtract if it's truly postfix: "expression if condition" on one line
          # NOT: "x = if cond" (that's a block), NOT lines with else/end
          %w[if unless while until].each do |kw|
            if stripped =~ /\S+\s+#{kw}\b/ && stripped !~ /[=(]\s*#{kw}\b/ && stripped !~ /\b(else|elsif|then|end|do)\b/
              opens -= 1
            end
          end
          closes = stripped.scan(/\bend\b/).size

          # Detect method start
          if stripped =~ /\bdef\s+(\w+[\?\!]?)/ && method_start.nil?
            method_start = idx
            method_name = $1
            keyword_depth = 1
            # Account for other opens on the same line as def (minus the def itself)
            keyword_depth += (opens - 1)
            keyword_depth -= closes
            next
          end

          if method_start
            keyword_depth += opens
            keyword_depth -= closes

            if keyword_depth <= 0
              methods << { name: method_name, start_line: method_start, end_line: idx }
              method_start = nil
              method_name = nil
              keyword_depth = 0
            end
          end
        end
        methods
      end

      def find_class_line(content)
        content.lines.each_with_index do |line, idx|
          return idx + 1 if line =~ /^\s*class\s+\w+/
        end
        1
      end
    end
  end
end
