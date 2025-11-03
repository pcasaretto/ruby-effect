# frozen_string_literal: true

require_relative "effect/version"
require_relative "effect/context"
require_relative "effect/cause"
require_relative "effect/task"
require_relative "effect/runtime"
require_relative "effect/layer"
require_relative "effect/schedule"
require_relative "effect/stream"
require_relative "effect/layers"
require_relative "effect/prelude"

module Effect
  # Namespace placeholder so require order doesn't matter when users `include Effect`.
end
