# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Evaluators::Normalizers::ResponseApiNormalizer do
  subject(:normalizer) { described_class.new }

  describe "#normalize_single_response" do
    context "with string input" do
      it "wraps string in standard format" do
        result = normalizer.normalize_single_response("Hello world")

        expect(result).to eq({
          text: "Hello world",
          tool_calls: [],
          metadata: {}
        })
      end
    end

    context "with Response API format" do
      it "extracts text from output array" do
        response = {
          "output" => [
            {
              "type" => "message",
              "role" => "assistant",
              "content" => [
                { "type" => "output_text", "text" => "Hello from Response API" }
              ]
            }
          ]
        }

        result = normalizer.normalize_single_response(response)

        expect(result[:text]).to eq("Hello from Response API")
      end

      it "extracts function calls" do
        response = {
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_xyz",
              "name" => "get_weather",
              "arguments" => '{"city": "London"}'
            }
          ]
        }

        result = normalizer.normalize_single_response(response)

        expect(result[:tool_calls]).to eq([
          {
            id: "call_xyz",
            type: "function",
            function_name: "get_weather",
            arguments: { "city" => "London" }
          }
        ])
      end

      it "extracts metadata" do
        response = {
          "id" => "resp_123",
          "model" => "gpt-4o",
          "status" => "completed",
          "usage" => { "total_tokens" => 50 },
          "output" => []
        }

        result = normalizer.normalize_single_response(response)

        expect(result[:metadata]).to include(
          id: "resp_123",
          model: "gpt-4o",
          status: "completed"
        )
      end
    end
  end

  describe "#normalize_conversation" do
    it "converts output to messages" do
      raw_data = {
        "output" => [
          {
            "type" => "message",
            "role" => "assistant",
            "content" => [
              { "type" => "output_text", "text" => "Hello!" }
            ]
          }
        ]
      }

      result = normalizer.normalize_conversation(raw_data)

      expect(result[:messages].length).to eq(1)
      expect(result[:messages][0][:role]).to eq("assistant")
      expect(result[:messages][0][:content]).to eq("Hello!")
    end

    it "extracts tool usage from function calls" do
      raw_data = {
        "output" => [
          {
            "type" => "function_call",
            "call_id" => "call_abc",
            "name" => "search",
            "arguments" => '{"query": "test"}'
          }
        ]
      }

      result = normalizer.normalize_conversation(raw_data)

      expect(result[:tool_usage].length).to eq(1)
      expect(result[:tool_usage][0][:function_name]).to eq("search")
      expect(result[:tool_usage][0][:call_id]).to eq("call_abc")
    end

    it "extracts file search results" do
      raw_data = {
        "output" => [
          {
            "type" => "file_search_call",
            "query" => "company policy",
            "results" => [
              { "filename" => "policy.pdf", "score" => 0.95 },
              { "filename" => "handbook.pdf", "score" => 0.85 }
            ]
          }
        ]
      }

      result = normalizer.normalize_conversation(raw_data)

      expect(result[:file_search_results].length).to eq(1)
      expect(result[:file_search_results][0][:query]).to eq("company policy")
      expect(result[:file_search_results][0][:files]).to eq([ "policy.pdf", "handbook.pdf" ])
      expect(result[:file_search_results][0][:scores]).to eq([ 0.95, 0.85 ])
    end

    context "web search results" do
      it "extracts web search results with action.sources (when include parameter used)" do
        raw_data = {
          "output" => [
            {
              "type" => "web_search_call",
              "id" => "ws_123",
              "status" => "completed",
              "action" => {
                "query" => "Ruby on Rails features",
                "sources" => [
                  { "title" => "Rails Blog", "url" => "https://rubyonrails.org/blog", "snippet" => "Rails 8..." },
                  { "title" => "GitHub", "url" => "https://github.com/rails/rails", "snippet" => "Open source..." }
                ]
              }
            }
          ]
        }

        result = normalizer.normalize_conversation(raw_data)

        expect(result[:web_search_results].length).to eq(1)
        expect(result[:web_search_results][0][:id]).to eq("ws_123")
        expect(result[:web_search_results][0][:status]).to eq("completed")
        expect(result[:web_search_results][0][:query]).to eq("Ruby on Rails features")
        expect(result[:web_search_results][0][:sources].length).to eq(2)
        expect(result[:web_search_results][0][:sources][0][:title]).to eq("Rails Blog")
        expect(result[:web_search_results][0][:sources][0][:url]).to eq("https://rubyonrails.org/blog")
        expect(result[:web_search_results][0][:citations]).to eq([])
      end

      it "extracts web search results with url_citation annotations (always present)" do
        raw_data = {
          "output" => [
            {
              "type" => "web_search_call",
              "id" => "ws_456",
              "status" => "completed",
              "action" => {
                "query" => "Nvidia AI market position"
              }
            },
            {
              "type" => "message",
              "status" => "completed",
              "content" => [
                {
                  "type" => "output_text",
                  "text" => "Nvidia dominates the AI chip market...",
                  "annotations" => [
                    {
                      "type" => "url_citation",
                      "start_index" => 0,
                      "end_index" => 50,
                      "title" => "Nvidia AI Dominance",
                      "url" => "https://example.com/nvidia-ai"
                    },
                    {
                      "type" => "url_citation",
                      "start_index" => 51,
                      "end_index" => 100,
                      "title" => "Market Analysis",
                      "url" => "https://example.com/market-analysis"
                    }
                  ]
                }
              ]
            }
          ]
        }

        result = normalizer.normalize_conversation(raw_data)

        expect(result[:web_search_results].length).to eq(1)
        expect(result[:web_search_results][0][:id]).to eq("ws_456")
        expect(result[:web_search_results][0][:query]).to eq("Nvidia AI market position")
        expect(result[:web_search_results][0][:sources]).to eq([])
        expect(result[:web_search_results][0][:citations].length).to eq(2)
        expect(result[:web_search_results][0][:citations][0][:title]).to eq("Nvidia AI Dominance")
        expect(result[:web_search_results][0][:citations][0][:url]).to eq("https://example.com/nvidia-ai")
        expect(result[:web_search_results][0][:citations][0][:start_index]).to eq(0)
        expect(result[:web_search_results][0][:citations][0][:end_index]).to eq(50)
      end

      it "extracts query from action.queries array" do
        raw_data = {
          "output" => [
            {
              "type" => "web_search_call",
              "id" => "ws_789",
              "status" => "completed",
              "action" => {
                "queries" => [ "first query", "second query" ]
              }
            }
          ]
        }

        result = normalizer.normalize_conversation(raw_data)

        expect(result[:web_search_results][0][:query]).to eq("first query")
      end

      it "handles both sources and citations (hybrid approach)" do
        raw_data = {
          "output" => [
            {
              "type" => "web_search_call",
              "id" => "ws_hybrid",
              "status" => "completed",
              "action" => {
                "query" => "test query",
                "sources" => [
                  { "title" => "Source 1", "url" => "https://source1.com", "snippet" => "..." },
                  { "title" => "Source 2", "url" => "https://source2.com", "snippet" => "..." }
                ]
              }
            },
            {
              "type" => "message",
              "content" => [
                {
                  "type" => "output_text",
                  "text" => "Response text",
                  "annotations" => [
                    {
                      "type" => "url_citation",
                      "title" => "Citation 1",
                      "url" => "https://citation1.com",
                      "start_index" => 0,
                      "end_index" => 10
                    }
                  ]
                }
              ]
            }
          ]
        }

        result = normalizer.normalize_conversation(raw_data)

        expect(result[:web_search_results][0][:sources].length).to eq(2)
        expect(result[:web_search_results][0][:citations].length).to eq(1)
      end
    end

    it "extracts code interpreter results" do
      raw_data = {
        "output" => [
          {
            "type" => "code_interpreter_call",
            "id" => "ci_456",
            "status" => "completed",
            "code_interpreter" => {
              "code" => "import pandas as pd\ndf = pd.read_csv('data.csv')\nprint(df.describe())",
              "language" => "python",
              "output" => "       value\ncount  100.0\nmean    42.5",
              "files_created" => [ "file_xyz" ]
            }
          }
        ]
      }

      result = normalizer.normalize_conversation(raw_data)

      expect(result[:code_interpreter_results].length).to eq(1)
      expect(result[:code_interpreter_results][0][:id]).to eq("ci_456")
      expect(result[:code_interpreter_results][0][:status]).to eq("completed")
      expect(result[:code_interpreter_results][0][:code]).to include("import pandas")
      expect(result[:code_interpreter_results][0][:language]).to eq("python")
      expect(result[:code_interpreter_results][0][:output]).to include("mean")
      expect(result[:code_interpreter_results][0][:files_created]).to eq([ "file_xyz" ])
    end

    it "handles multiple tool types in same output" do
      raw_data = {
        "output" => [
          {
            "type" => "web_search_call",
            "id" => "ws_1",
            "status" => "completed",
            "action" => { "query" => "test query" },
            "sources" => []
          },
          {
            "type" => "code_interpreter_call",
            "id" => "ci_1",
            "status" => "completed",
            "code_interpreter" => {
              "code" => "print('hello')",
              "output" => "hello"
            }
          },
          {
            "type" => "message",
            "role" => "assistant",
            "content" => [ { "type" => "output_text", "text" => "Done!" } ]
          }
        ]
      }

      result = normalizer.normalize_conversation(raw_data)

      expect(result[:web_search_results].length).to eq(1)
      expect(result[:code_interpreter_results].length).to eq(1)
      expect(result[:messages].length).to eq(1)
    end
  end
end
