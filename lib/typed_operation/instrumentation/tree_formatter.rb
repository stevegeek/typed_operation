# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Instrumentation
    # Formats execution traces as a visual chain for console output.
    # Shows operation flow with arrows and pass mode indicators.
    class TreeFormatter
      ARROW = "→" #: String
      FALLBACK_ARROW = "⤷" #: String

      SUCCESS_MARK = "✓" #: String
      FAILURE_MARK = "✗" #: String
      SKIPPED_MARK = "○" #: String

      PASS_MODES = {
        kwargs_splat: "**ctx",
        single_value: "ctx",
        transform: "transform",
        fallback: "fallback"
      }.freeze #: Hash[Symbol, String]

      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        cyan: "\e[36m",
        dim: "\e[2m",
        bold: "\e[1m",
        reset: "\e[0m"
      }.freeze #: Hash[Symbol, String]

      # @rbs @color: bool

      #: (?color: bool?) -> void
      def initialize(color: nil)
        @color = color.nil? ? detect_color_support : color
      end

      #: (Trace) -> String
      def format(trace)
        lines = [] #: Array[String]
        format_chain(trace, lines)
        lines.join("\n")
      end

      private

      #: (Trace, Array[String], ?depth: Integer, ?is_fallback: bool) -> void
      def format_chain(trace, lines, depth: 0, is_fallback: false)
        indent = "  " * depth

        status = format_status(trace)
        duration = format_duration(trace.duration_ms)
        pass_info = format_pass_mode(trace)

        op_name = trace.operation_name
        if is_fallback
          op_name = "#{colorize(FALLBACK_ARROW, :yellow)} #{op_name}"
        end

        line = "#{indent}#{op_name} #{duration} #{status}"

        if pass_info
          line = "#{line} #{pass_info}"
        end

        extracted = trace.extracted_params
        if extracted&.any?
          params_str = extracted.join(", ")
          line = "#{line} #{colorize("← [#{params_str}]", :dim)}"
        end

        lines << line

        if trace.exception
          lines << "#{indent}  #{colorize("└ Exception: #{trace.exception.class}: #{trace.exception.message}", :red)}"
        elsif trace.failure? && trace.result.respond_to?(:failure)
          failure_info = trace.result.failure
          lines << "#{indent}  #{colorize("└ Failure: #{failure_info.inspect}", :red)}"
        end

        trace.children.each_with_index do |child, index|
          is_child_fallback = child.fallback_used

          if index == 0 || is_child_fallback
            arrow = is_child_fallback ? FALLBACK_ARROW : ARROW
            arrow_color = is_child_fallback ? :yellow : :dim
            lines << "#{indent}  #{colorize(arrow, arrow_color)}"
          else
            lines << "#{indent}  #{colorize(ARROW, :dim)}"
          end

          format_chain(child, lines, depth: depth, is_fallback: is_child_fallback)
        end
      end

      #: (Trace) -> String
      def format_status(trace)
        if trace.exception
          colorize(FAILURE_MARK, :red)
        elsif trace.failure?
          colorize(FAILURE_MARK, :red)
        else
          colorize(SUCCESS_MARK, :green)
        end
      end

      #: (Float | Integer | nil) -> String
      def format_duration(ms)
        return colorize("[--ms]", :dim) unless ms
        colorize("[#{ms}ms]", :dim)
      end

      #: (Trace) -> String?
      def format_pass_mode(trace)
        return nil unless trace.pass_mode
        mode_str = PASS_MODES[trace.pass_mode] || trace.pass_mode.to_s
        colorize("(#{mode_str})", :cyan)
      end

      #: (Exception?) -> String
      def format_exception(exception)
        return "" unless exception
        colorize("(#{exception.class}: #{exception.message})", :red)
      end

      #: (String, Symbol) -> String
      def colorize(text, color)
        return text unless @color
        "#{COLORS[color]}#{text}#{COLORS[:reset]}"
      end

      #: () -> bool
      def detect_color_support
        return false unless $stdout.respond_to?(:tty?)
        $stdout.tty? && ENV["TERM"] != "dumb" && !ENV["NO_COLOR"]
      end
    end
  end
end
