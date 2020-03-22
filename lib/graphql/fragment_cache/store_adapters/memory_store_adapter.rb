# frozen_string_literal: true

module GraphQL
  module FragmentCache
    module StoreAdapters
      # Memory adapter for storing cached fragments
      class MemoryStoreAdapter < BaseStoreAdapter
        def initialize(_options)
          @storage = {}
        end

        def get(key)
          @storage[key]
        end

        def set(key, value, **options)
          if options[:ex]
            raise ArgumentError,
                  ":memory adapter does not accept :ex parameter, consider switching to :redis"
          end

          @storage[key] = value
        end

        def del(key)
          @storage.delete(key)
        end
      end
    end
  end
end