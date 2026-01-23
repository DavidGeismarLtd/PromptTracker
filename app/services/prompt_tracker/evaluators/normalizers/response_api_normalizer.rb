# frozen_string_literal: true

module PromptTracker
  module Evaluators
    module Normalizers
      # Normalizer for OpenAI Response API responses.
      #
      # The Response API is OpenAI's newer stateful conversation API.
      # It maintains conversation state on the server side and returns
      # responses with a different structure than Chat Completion.
      #
      # @example Normalize a response
      #   normalizer = ResponseApiNormalizer.new
      #   normalized = normalizer.normalize_single_response(response)
      #
      class ResponseApiNormalizer < BaseNormalizer
        # Normalize a single response from Response API
        #
        # @param raw_response [Hash, String] the raw response
        # @return [Hash] normalized single response format
        def normalize_single_response(raw_response)
          case raw_response
          when String
            { text: raw_response, tool_calls: [], metadata: {} }
          when Hash
            {
              text: extract_text(raw_response),
              tool_calls: extract_tool_calls(raw_response),
              metadata: extract_metadata(raw_response)
            }
          else
            { text: raw_response.to_s, tool_calls: [], metadata: {} }
          end
        end

        # Normalize a conversation from Response API
        #
        # @param raw_data [Hash] the raw conversation data
        # @return [Hash] normalized conversation format
        def normalize_conversation(raw_data)
          # Response API returns output array with items
          output = raw_data[:output] || raw_data["output"] || []
          messages = raw_data[:messages] || raw_data["messages"] || []

          # Combine output items and any messages
          all_messages = messages.presence || output_to_messages(output)

          {
            messages: normalize_messages(all_messages),
            tool_usage: extract_tool_usage(output),
            file_search_results: extract_file_search_results(output),
            web_search_results: extract_web_search_results(output),
            code_interpreter_results: extract_code_interpreter_results(output),
            run_steps: []  # Response API doesn't have run_steps
          }
        end

        private

        def extract_text(response)
          # Response API structure: output[].content[].text
          output = response[:output] || response["output"] || []

          # Find message items and extract text
          text_parts = output.flat_map do |item|
            next [] unless (item[:type] || item["type"]) == "message"

            content = item[:content] || item["content"] || []
            content.filter_map do |c|
              c[:text] || c["text"] if (c[:type] || c["type"]) == "output_text"
            end
          end

          text_parts.join("\n").presence || response[:text] || response["text"] || ""
        end

        def extract_tool_calls(response)
          output = response[:output] || response["output"] || []

          output.filter_map do |item|
            next unless (item[:type] || item["type"]) == "function_call"

            {
              id: item[:call_id] || item["call_id"] || item[:id] || item["id"],
              type: "function",
              function_name: item[:name] || item["name"],
              arguments: parse_arguments(item[:arguments] || item["arguments"])
            }
          end
        end

        def extract_metadata(response)
          {
            id: response[:id] || response["id"],
            model: response[:model] || response["model"],
            status: response[:status] || response["status"],
            usage: response[:usage] || response["usage"]
          }.compact
        end

        def output_to_messages(output)
          output.filter_map do |item|
            type = item[:type] || item["type"]
            next unless type == "message"

            role = item[:role] || item["role"] || "assistant"
            content = item[:content] || item["content"] || []

            text = content.filter_map do |c|
              c[:text] || c["text"] if (c[:type] || c["type"]) == "output_text"
            end.join("\n")

            { role: role, content: text }
          end
        end

        def normalize_messages(messages)
          messages.map.with_index do |msg, index|
            {
              role: msg[:role] || msg["role"],
              content: extract_text_content(msg[:content] || msg["content"]),
              tool_calls: msg[:tool_calls] || msg["tool_calls"] || [],
              turn: msg[:turn] || msg["turn"] || index + 1
            }
          end
        end

        def extract_tool_usage(output)
          output.filter_map do |item|
            next unless (item[:type] || item["type"]) == "function_call"

            {
              function_name: item[:name] || item["name"],
              call_id: item[:call_id] || item["call_id"],
              arguments: parse_arguments(item[:arguments] || item["arguments"]),
              result: nil  # Results would need to be provided separately
            }
          end
        end

        def extract_file_search_results(output)
          output.filter_map do |item|
            next unless (item[:type] || item["type"]) == "file_search_call"

            results = item[:results] || item["results"] || []
            {
              query: item[:query] || item["query"],
              files: results.map { |r| r[:filename] || r["filename"] },
              scores: results.map { |r| r[:score] || r["score"] }
            }
          end
        end

        # Extract web search call results from Response API output
        #
        # Hybrid approach:
        # - Extracts queries from web_search_call.action.query or action.queries[0]
        # - Extracts sources from web_search_call.action.sources (if present via include parameter)
        # - Extracts citations from message.content[].annotations (always present)
        #
        # @param output [Array] the output array from Response API
        # @return [Array<Hash>] array of web search results with query, sources, and citations
        def extract_web_search_results(output)
          # Extract all URL citations from message annotations
          citations = extract_url_citations(output)

          # Extract web search calls and combine with citations
          output.filter_map do |item|
            next unless (item[:type] || item["type"]) == "web_search_call"

            {
              id: item[:id] || item["id"],
              status: item[:status] || item["status"],
              query: extract_web_search_query(item),
              sources: extract_web_search_sources_from_action(item),
              citations: citations
            }
          end
        end

        # Extract query from web search call item
        #
        # Handles both action.query (string) and action.queries (array)
        #
        # @param item [Hash] web_search_call item
        # @return [String, nil] the query string
        def extract_web_search_query(item)
          action = item[:action] || item["action"] || {}

          # Try action.query first (single query string)
          query = action[:query] || action["query"]
          return query if query.present?

          # Try action.queries (array of queries) - use first one
          queries = action[:queries] || action["queries"]
          return queries.first if queries.is_a?(Array) && queries.any?

          # Fallback to top-level query (legacy)
          item[:query] || item["query"]
        end

        # Extract sources from web_search_call.action.sources
        #
        # This field is only present when the API call includes:
        # include: ["web_search_call.action.sources"]
        #
        # @param item [Hash] web_search_call item
        # @return [Array<Hash>] array of source objects (empty if not included)
        def extract_web_search_sources_from_action(item)
          action = item[:action] || item["action"] || {}
          sources = action[:sources] || action["sources"] || []

          sources.map do |source|
            {
              title: source[:title] || source["title"],
              url: source[:url] || source["url"],
              snippet: source[:snippet] || source["snippet"]
            }
          end
        end

        # Extract URL citations from message annotations
        #
        # Citations are always present in the response and show which URLs
        # were actually cited in the response text.
        #
        # @param output [Array] the output array from Response API
        # @return [Array<Hash>] array of citation objects
        def extract_url_citations(output)
          output.flat_map do |item|
            next [] unless (item[:type] || item["type"]) == "message"

            content = item[:content] || item["content"] || []
            content.flat_map do |c|
              annotations = c[:annotations] || c["annotations"] || []
              annotations.filter_map do |ann|
                next unless (ann[:type] || ann["type"]) == "url_citation"

                {
                  title: ann[:title] || ann["title"],
                  url: ann[:url] || ann["url"],
                  start_index: ann[:start_index] || ann["start_index"],
                  end_index: ann[:end_index] || ann["end_index"]
                }
              end
            end
          end
        end

        # Extract code interpreter call results from Response API output
        #
        # @param output [Array] the output array from Response API
        # @return [Array<Hash>] array of code interpreter results
        def extract_code_interpreter_results(output)
          output.filter_map do |item|
            type = item[:type] || item["type"]
            next unless type == "code_interpreter_call"

            ci = item[:code_interpreter] || item["code_interpreter"] || {}
            {
              id: item[:id] || item["id"],
              status: item[:status] || item["status"],
              code: ci[:code] || ci["code"] || item[:code] || item["code"],
              language: ci[:language] || ci["language"] || detect_language(ci[:code] || ci["code"]),
              output: extract_code_output(ci),
              files_created: ci[:files_created] || ci["files_created"] || [],
              error: ci[:error] || ci["error"]
            }
          end
        end

        def extract_code_output(code_interpreter)
          # Output may be in various formats
          output = code_interpreter[:output] || code_interpreter["output"]
          return output if output.is_a?(String)

          # May be an array of output items
          if output.is_a?(Array)
            output.filter_map do |o|
              o[:text] || o["text"] || o[:logs] || o["logs"]
            end.join("\n")
          else
            output.to_s
          end
        end

        def detect_language(code)
          return nil if code.nil?

          # Simple heuristic detection
          return "python" if code.include?("import ") || code.include?("def ") || code.include?("print(")
          return "javascript" if code.include?("const ") || code.include?("let ") || code.include?("function ")
          return "ruby" if code.include?("require ") || code.include?("def ") && code.include?("end")

          nil
        end
      end
    end
  end
end
