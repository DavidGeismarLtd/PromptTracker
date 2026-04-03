# Migration Policy

This document defines how we manage **database migrations** for the PromptTracker Rails engine.
It is aimed at contributors working on the engine and the dummy app.

- **Engine migrations live in** `db/migrate/` (inside the gem/engine).
- **Dummy app migrations live in** `test/dummy/db/migrate/` and are copies of the engine migrations.

The goals:

- Keep the schema **simple to understand**.
- Give users a **predictable upgrade path** once the gem is used in real apps.
- Avoid ad‑hoc backward‑compatibility logic in Ruby code – **use migrations instead of dual reads**.

---

## 1. Pre‑release policy (current state)

"Pre‑release" here means: before we commit to a version that real external apps rely on
(e.g. before a widely used `1.0.0` or similar stable release).

During this phase we treat local databases as **disposable** and optimise for clarity.

### 1.1 Canonical schema migration

- The engine must have **one canonical migration**:
  - `db/migrate/20251216000001_create_prompt_tracker_schema.rb`
- That migration must:
  - Create **all PromptTracker tables** (`prompt_tracker_agents`, `prompt_tracker_agent_versions`,
    `prompt_tracker_llm_responses`, `prompt_tracker_deployed_agents`, `prompt_tracker_task_runs`, etc.).
  - Use the **current naming** (`Agent`, `AgentVersion`), not legacy `Prompt`/`PromptVersion`.
  - Match the structure that a fresh `test/dummy` database should have.
- There should be **no additional migrations** in the engine for the current pre‑release phase
  (no rename migrations, no incremental add‑column migrations that only existed during development).

### 1.2 Dummy app migrations

- The dummy app keeps a **copy** of that canonical migration in
  `test/dummy/db/migrate/*_create_prompt_tracker_schema.prompt_tracker.rb`.
- There should be **only one** `prompt_tracker` migration file in the dummy app as well.
- We keep the dummy app in sync with the engine by running:

  ```bash
  cd test/dummy
  bin/rails prompt_tracker:install:migrations
  ```

  and deleting any obsolete `prompt_tracker` migrations that are no longer present in the engine.

### 1.3 Making schema changes during pre‑release

When you need to change the schema **before** a stable release:

1. **Edit the canonical engine migration in place**:
   - Update `db/migrate/20251216000001_create_prompt_tracker_schema.rb` so that running it on a
     fresh database produces the desired schema.
2. **Sync the dummy migration**:
   - Run `cd test/dummy && bin/rails prompt_tracker:install:migrations`.
   - Ensure only the `create_prompt_tracker_schema.prompt_tracker.rb` migration exists for PromptTracker.
3. **Rebuild the dummy database** (local only):
   - `cd test/dummy`
   - `bin/rails db:drop db:create db:migrate`
   - (Optionally) `bin/rails db:seed`
4. **Run tests** from the engine root:
   - `bin/test_all` or the smallest relevant subset.

We explicitly **allow squashing and rewriting** the canonical migration during this phase.
Contributors should assume that local databases may need to be dropped and recreated after schema changes.

---

## 2. Post‑release policy (after external users depend on the gem)

Once we have published a version that real applications depend on, we switch to an
**append‑only migration policy**.

### 2.1 Engine migrations

- Existing migrations in `db/migrate/` are **never edited** (except for trivial typos
  caught before a release is published).
- Any schema change is done via a **new migration file** (e.g. `add_column`, `rename_column`,
  `rename_table`, `add_index`, etc.).
- We do **not** maintain backward‑compatibility Ruby code that handles multiple data shapes.
  Instead, we:
  - Write proper migrations to transform data.
  - Assume users run those migrations when upgrading.

### 2.2 Dummy app migrations

- After adding a new migration to the engine, run:

  ```bash
  cd test/dummy
  bin/rails prompt_tracker:install:migrations
  bin/rails db:migrate
  ```

- The dummy app should end up with **all** PromptTracker migrations that a host app would see
  (the original `create_prompt_tracker_schema` plus any incremental migrations).

### 2.3 Breaking / large changes

If we need a major, breaking schema redesign:

- Prefer a **new major version** of the gem with a clear upgrade path.
- Provide a sequence of migrations that brings existing databases from the old schema
  to the new schema.
- Still avoid dual‑format logic in Ruby (no long‑term support for both old and new
  column names or table names in the code).

---

## 3. Design principles

These principles apply in both pre‑release and post‑release phases:

1. **No defensive hash access for known schemas**
   - Use symbol keys only (e.g. `model_config[:provider]`), not fallbacks to string keys.
   - Trust the schema and migrations to keep data in the expected format.

2. **No long‑term backward‑compatibility code**
   - When formats change, update the data via migrations instead of handling both
     old and new formats in the application code.

3. **Tests for migration‑driven behaviour**
   - When adding schema that drives behaviour (e.g. task agents, deployment tracking),
     ensure there are RSpec examples that exercise that behaviour using the
     migrated schema.

4. **Engine as source of truth**
   - The engine’s migrations are the **source of truth**.
   - The dummy app and host apps must obtain migrations from the engine via
     `prompt_tracker:install:migrations`, not by hand‑editing copies.

