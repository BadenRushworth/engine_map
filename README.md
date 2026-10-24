# EngineMap

Asset helpers and an install generator for Rails engines (Rails 8, importmap, Stimulus), on Propshaft or Sprockets.

EngineMap gives you:

- `engine_stylesheet_link_tags "my_engine", :all` links every CSS file in the engine's stylesheet folder, with digests.
- Importmap modes: merge the engine's pins into the host's map, use an independent map, or both.
- Namespaced Stimulus controllers that can't collide with the host's.
- An install generator that injects into existing files, backs up anything it replaces, and is safe to re-run.

No database, no routes, no models.

## Install

Add the gem to the engine's (or host app's) Gemfile, then run the generator:

```ruby
gem "engine_map"
```

```sh
bundle install
bin/rails g engine_map:install
```

Run it from inside an engine and that engine is pre-selected. Otherwise you get a numbered list of the engines your app has loaded. The host app is listed too.

| Option | Values | Default |
|---|---|---|
| `--engine NAME` | skip the prompt | |
| `--importmap` | `merge`, `own`, `both` | `merge` |
| `--stimulus` | `host`, `own`, `none` | `host` |
| `--all` | also list engines from installed gems | off |

## What the generator changes

- `lib/<engine>/engine.rb`: adds `require "engine_map"` and `EngineMap.configure(self)`.
- `<engine>.gemspec`: adds `spec.add_dependency "engine_map"`.
- `config/importmap.rb`, `app/javascript/<engine>/...` and a starter stylesheet are created if missing.
- The engine's layout: its own stylesheet tag is replaced by `engine_stylesheet_link_tags`, and importmap tags are added.

When a line is replaced, the file gets a `.backup` next to it (never overwritten: `.backup.1`, ...). If a file or anchor can't be found, the generator prints the exact lines to add by hand. Running it twice changes nothing and says so.

## Importmap modes

A page can only render one import map, so each layout picks one.

**merge (default).** The engine's pins join the host's map. Use the normal `javascript_importmap_tags` plus `javascript_import_module_tag "my_engine/application"`.

**own.** The engine has an independent map, with a helper named after the engine:

```erb
<%= my_engine_javascript_importmap_tags %>
```

**both** enables both and generates `app/views/layouts/my_engine/standalone.html.erb`, an independent layout the engine can opt into.

## Stimulus

Controllers live in `app/javascript/my_engine/controllers/` and are pinned as `controllers/my_engine/...`, so the host's `eagerLoadControllersFrom("controllers", ...)` finds them. Identifiers are namespaced:

```erb
<div data-controller="my-engine--example"></div>
```

With `--stimulus own`, the engine also gets `my_engine/standalone.js`, which starts its own Stimulus application. Only the engine's own importmap helper loads it, never a merged layout.

## Sprockets

The engine registers its own CSS and JS for precompile, so the host's `manifest.js` needs no engine-specific lines. A Sprockets host must still link its own `app/javascript` in `manifest.js`. When the target is a host app, the generator checks this and adds the lines if missing.

## Development

```sh
bin/test                                              # Propshaft
BUNDLE_GEMFILE=gemfiles/sprockets.gemfile bin/test    # Sprockets
bundle exec rake test:pipelines                       # both
```

## License

MIT.
