# Session Store Configuration

## Overview

This application uses **cache-based session storage** instead of the default cookie-based storage to support larger session data, particularly for playground conversation history.

## Why Cache Store?

**Problem**: Cookie-based sessions have a 4KB size limit. Playground conversations with multiple messages quickly exceed this limit, causing `ActionDispatch::Cookies::CookieOverflow` errors.

**Solution**: Store sessions in Redis cache, which has no practical size limit for conversation data.

## Configuration

### Session Store
- **File**: `config/initializers/session_store.rb`
- **Store Type**: `:cache_store`
- **Expiration**: 24 hours of inactivity
- **Key**: `_prompt_tracker_session`

### Cache Configuration

#### Development Environment
- **Redis URL**: `redis://localhost:6379/2` (DB 2)
- **Expiration**: 24 hours
- **Always enabled**: Even when `rails dev:cache` is off

#### Test Environment
- **Store Type**: `:memory_store`
- **No Redis dependency**: Tests run without external services

#### Production Environment
- **Redis URL**: From `REDIS_URL` environment variable
- **Recommended**: Use Redis DB 2 for sessions (DB 0 for Sidekiq, DB 1 for ActionCable)

## Redis Database Allocation

```
redis://localhost:6379/0  → Sidekiq (background jobs)
redis://localhost:6379/1  → ActionCable (WebSocket connections)
redis://localhost:6379/2  → Session cache (NEW)
```

## Conversation Cleanup

### Automatic Cleanup
- Sessions expire after **24 hours of inactivity**
- Redis automatically removes expired keys

### Manual Cleanup
- User clicks "Reset" button in playground
- Calls `clear_conversation_state()` in controller
- Immediately removes session data from Redis

## Benefits

✅ **No size limits** - Store 100+ messages without overflow errors  
✅ **Automatic expiration** - Old sessions cleaned up automatically  
✅ **Manual reset** - "Reset" button works as expected  
✅ **No code changes** - Existing service/controller code unchanged  
✅ **Uses existing Redis** - No new infrastructure needed  

## Testing

To verify the setup works:

1. Start Redis: `redis-server`
2. Start Rails: `bin/rails s`
3. Open playground and send multiple long messages
4. Verify no cookie overflow errors
5. Click "Reset" and verify conversation clears
6. Check Redis: `redis-cli -n 2 KEYS "*session*"`

