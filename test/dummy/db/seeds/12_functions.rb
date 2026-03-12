# frozen_string_literal: true

# ============================================================================
# FUNCTION LIBRARY SEEDS
# ============================================================================
# This file creates example functions for the Function Registry.
# These demonstrate different use cases and serve as templates for users.

puts "\n🔧 Seeding Function Library..."

# Clean up existing functions
PromptTracker::FunctionDefinition.destroy_all

# ============================================================================
# 1. Weather API Function
# ============================================================================
weather_function = PromptTracker::FunctionDefinition.create!(
  name: "get_weather",
  description: "Get current weather for a city using OpenWeatherMap API",
  category: "api",
  tags: [ "weather", "api", "external" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(city:, units: "metric")
      require 'net/http'
      require 'json'

      api_key = env['OPENWEATHER_API_KEY']
      base_url = "https://api.openweathermap.org/data/2.5/weather"

      uri = URI(base_url)
      uri.query = URI.encode_www_form({
        q: city,
        units: units,
        appid: api_key
      })

      response = Net::HTTP.get_response(uri)
      data = JSON.parse(response.body)

      {
        city: data['name'],
        temperature: data['main']['temp'],
        feels_like: data['main']['feels_like'],
        humidity: data['main']['humidity'],
        description: data['weather'][0]['description'],
        units: units
      }
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "city" => {
        "type" => "string",
        "description" => "City name (e.g., 'London', 'New York')"
      },
      "units" => {
        "type" => "string",
        "enum" => [ "metric", "imperial", "standard" ],
        "description" => "Temperature units (metric=Celsius, imperial=Fahrenheit)",
        "default" => "metric"
      }
    },
    "required" => [ "city" ]
  },
  environment_variables: {
    "OPENWEATHER_API_KEY" => "your_api_key_here"
  },
  dependencies: [],
  example_input: {
    "city" => "Berlin",
    "units" => "metric"
  },
  example_output: {
    "city" => "Berlin",
    "temperature" => 15.2,
    "feels_like" => 14.1,
    "humidity" => 72,
    "description" => "partly cloudy",
    "units" => "metric"
  },
  created_by: "system"
)

puts "  ✓ Created weather API function"

# ============================================================================
# 2. Simple Calculator Function
# ============================================================================
calculator_function = PromptTracker::FunctionDefinition.create!(
  name: "calculate",
  description: "Perform basic arithmetic operations (add, subtract, multiply, divide)",
  category: "utility",
  tags: [ "math", "calculator", "utility" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(operation:, a:, b:)
      case operation
      when "add"
        a + b
      when "subtract"
        a - b
      when "multiply"
        a * b
      when "divide"
        raise ArgumentError, "Cannot divide by zero" if b.zero?
        a.to_f / b
      else
        raise ArgumentError, "Unknown operation: #{operation}"
      end
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "operation" => {
        "type" => "string",
        "enum" => [ "add", "subtract", "multiply", "divide" ],
        "description" => "The arithmetic operation to perform"
      },
      "a" => {
        "type" => "number",
        "description" => "First operand"
      },
      "b" => {
        "type" => "number",
        "description" => "Second operand"
      }
    },
    "required" => [ "operation", "a", "b" ]
  },
  dependencies: [],
  example_input: {
    "operation" => "multiply",
    "a" => 6,
    "b" => 7
  },
  example_output: 42,
  created_by: "system"
)

puts "  ✓ Created calculator function"

# ============================================================================
# 3. Text Processing Function
# ============================================================================
text_processor = PromptTracker::FunctionDefinition.create!(
  name: "process_text",
  description: "Process text with various transformations (uppercase, lowercase, reverse, word count)",
  category: "utility",
  tags: [ "text", "string", "processing" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(text:, operation:)
      case operation
      when "uppercase"
        text.upcase
      when "lowercase"
        text.downcase
      when "reverse"
        text.reverse
      when "word_count"
        text.split.length
      when "char_count"
        text.length
      when "titlecase"
        text.split.map(&:capitalize).join(' ')
      else
        raise ArgumentError, "Unknown operation: #{operation}"
      end
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "text" => {
        "type" => "string",
        "description" => "The text to process"
      },
      "operation" => {
        "type" => "string",
        "enum" => [ "uppercase", "lowercase", "reverse", "word_count", "char_count", "titlecase" ],
        "description" => "The transformation to apply"
      }
    },
    "required" => [ "text", "operation" ]
  },
  dependencies: [],
  example_input: {
    "text" => "hello world",
    "operation" => "titlecase"
  },
  example_output: "Hello World",
  created_by: "system"
)

puts "  ✓ Created text processing function"

# ============================================================================
# 4. JSON Validator Function
# ============================================================================
json_validator = PromptTracker::FunctionDefinition.create!(
  name: "validate_json",
  description: "Validate JSON string and return parsed object or error details",
  category: "validation",
  tags: [ "json", "validation", "parsing" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(json_string:)
      require 'json'

      begin
        parsed = JSON.parse(json_string)
        {
          valid: true,
          data: parsed,
          error: nil
        }
      rescue JSON::ParserError => e
        {
          valid: false,
          data: nil,
          error: e.message
        }
      end
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "json_string" => {
        "type" => "string",
        "description" => "JSON string to validate"
      }
    },
    "required" => [ "json_string" ]
  },
  dependencies: [],
  example_input: {
    "json_string" => '{"name": "John", "age": 30}'
  },
  example_output: {
    "valid" => true,
    "data" => { "name" => "John", "age" => 30 },
    "error" => nil
  },
  created_by: "system"
)

puts "  ✓ Created JSON validator function"

# ============================================================================
# 5. URL Shortener Function (Mock)
# ============================================================================
url_shortener = PromptTracker::FunctionDefinition.create!(
  name: "shorten_url",
  description: "Shorten a URL using a URL shortening service API",
  category: "api",
  tags: [ "url", "api", "utility" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(url:)
      require 'net/http'
      require 'json'

      api_key = env['BITLY_API_KEY']

      uri = URI('https://api-ssl.bitly.com/v4/shorten')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = { long_url: url }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      data = JSON.parse(response.body)

      {
        original_url: url,
        short_url: data['link'],
        created_at: data['created_at']
      }
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "url" => {
        "type" => "string",
        "format" => "uri",
        "description" => "The URL to shorten"
      }
    },
    "required" => [ "url" ]
  },
  environment_variables: {
    "BITLY_API_KEY" => "your_bitly_api_key_here"
  },
  dependencies: [],
  example_input: {
    "url" => "https://www.example.com/very/long/url/path"
  },
  example_output: {
    "original_url" => "https://www.example.com/very/long/url/path",
    "short_url" => "https://bit.ly/abc123",
    "created_at" => "2024-03-12T10:30:00Z"
  },
  created_by: "system"
)

puts "  ✓ Created URL shortener function"

# ============================================================================
# 6. Email Validator Function
# ============================================================================
email_validator = PromptTracker::FunctionDefinition.create!(
  name: "validate_email",
  description: "Validate email address format and check domain MX records",
  category: "validation",
  tags: [ "email", "validation", "regex" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(email:)
      # Basic email regex pattern
      email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

      format_valid = email.match?(email_regex)

      {
        email: email,
        format_valid: format_valid,
        has_at_symbol: email.include?('@'),
        has_domain: email.split('@').length == 2 && email.split('@')[1].include?('.'),
        local_part: email.split('@')[0],
        domain: email.split('@')[1]
      }
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "email" => {
        "type" => "string",
        "description" => "Email address to validate"
      }
    },
    "required" => [ "email" ]
  },
  dependencies: [],
  example_input: {
    "email" => "user@example.com"
  },
  example_output: {
    "email" => "user@example.com",
    "format_valid" => true,
    "has_at_symbol" => true,
    "has_domain" => true,
    "local_part" => "user",
    "domain" => "example.com"
  },
  created_by: "system"
)

puts "  ✓ Created email validator function"

# ============================================================================
# 7. Random Generator Function
# ============================================================================
random_generator = PromptTracker::FunctionDefinition.create!(
  name: "generate_random",
  description: "Generate random data (numbers, strings, UUIDs, passwords)",
  category: "utility",
  tags: [ "random", "generator", "uuid" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(type:, length: 10)
      require 'securerandom'

      case type
      when "number"
        rand(1..length)
      when "string"
        SecureRandom.alphanumeric(length)
      when "uuid"
        SecureRandom.uuid
      when "hex"
        SecureRandom.hex(length / 2)
      when "password"
        # Generate password with letters, numbers, and symbols
        chars = [('a'..'z'), ('A'..'Z'), ('0'..'9'), ['!', '@', '#', '$', '%']].map(&:to_a).flatten
        Array.new(length) { chars.sample }.join
      else
        raise ArgumentError, "Unknown type: #{type}"
      end
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "type" => {
        "type" => "string",
        "enum" => [ "number", "string", "uuid", "hex", "password" ],
        "description" => "Type of random data to generate"
      },
      "length" => {
        "type" => "integer",
        "description" => "Length of generated data (not applicable for UUID)",
        "default" => 10
      }
    },
    "required" => [ "type" ]
  },
  dependencies: [],
  example_input: {
    "type" => "password",
    "length" => 16
  },
  example_output: "aB3$xY9@mK2#pQ5!",
  created_by: "system"
)

puts "  ✓ Created random generator function"

# ============================================================================
# 8. Date/Time Formatter Function
# ============================================================================
datetime_formatter = PromptTracker::FunctionDefinition.create!(
  name: "format_datetime",
  description: "Format and manipulate dates and times",
  category: "utility",
  tags: [ "date", "time", "formatting" ],
  language: "ruby",
  code: <<~'RUBY',
    def execute(datetime_string:, format:, timezone: "UTC")
      require 'time'

      dt = Time.parse(datetime_string)

      case format
      when "iso8601"
        dt.iso8601
      when "rfc2822"
        dt.rfc2822
      when "unix"
        dt.to_i
      when "human"
        dt.strftime("%B %d, %Y at %I:%M %p")
      when "date_only"
        dt.strftime("%Y-%m-%d")
      when "time_only"
        dt.strftime("%H:%M:%S")
      when "custom"
        dt.strftime(timezone)
      else
        dt.to_s
      end
    end
  RUBY
  parameters: {
    "type" => "object",
    "properties" => {
      "datetime_string" => {
        "type" => "string",
        "description" => "Date/time string to parse"
      },
      "format" => {
        "type" => "string",
        "enum" => [ "iso8601", "rfc2822", "unix", "human", "date_only", "time_only", "custom" ],
        "description" => "Output format"
      },
      "timezone" => {
        "type" => "string",
        "description" => "Timezone (or custom strftime format if format=custom)",
        "default" => "UTC"
      }
    },
    "required" => [ "datetime_string", "format" ]
  },
  dependencies: [],
  example_input: {
    "datetime_string" => "2024-03-12 14:30:00",
    "format" => "human"
  },
  example_output: "March 12, 2024 at 02:30 PM",
  created_by: "system"
)

puts "  ✓ Created date/time formatter function"

puts "\n✅ Function Library seeded with 8 example functions"
