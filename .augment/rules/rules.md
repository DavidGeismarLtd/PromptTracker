---
type: "always_apply"
---

- create small testable classes
- Create tests for all classes using rspec
- Avoid Defensive programming (avoid rescuing StandardError in particular)
- User prefers to avoid defensive programming patterns when accessing hash keys with known formats. exemple Dont do this :
# Defensive pattern with fallback to string keys
provider = model_config[:provider] || model_config["provider"] || "openai"
api = model_config[:api] || model_config["api"]
tool_config = model_config[:tool_config] || {}
✅ Do this instead:
# Only symbol keys
model = model_config[:model]
temperature = model_config[:temperature]
- User prefers to remove backward compatibility code for legacy data formats instead of maintaining it.
❌ Don't do this:
