# frozen_string_literal: true

require "spec_helper"
require "json"
require "digest"

RSpec.describe GraphQL::FragmentCache::CacheKeyBuilder do
  let(:query_type) do
    Class.new(GraphQL::Schema::Object) do
      graphql_name "QueryType"

      field :cached_post, PostType, null: true do
        argument :id, GraphQL::Types::ID, required: true
        argument :context_dependent, GraphQL::Types::Boolean, required: false
        argument :context_cache_key, GraphQL::Types::String, required: false
      end

      field :post, PostType, null: true do
        argument :id, GraphQL::Types::ID, required: true
      end

      def cached_post(id:, context_dependent: nil, context_cache_key: nil)
        options = {}
        options[:context_dependent] = true if context_dependent
        options[:context_cache_key] = context_cache_key unless context_cache_key.nil?

        cache_fragment(options) { post(id: id) }
      end

      def post(id:)
        Post.find(id)
      end
    end
  end

  let(:id) { 1 }
  let(:variables) { { id: id } }
  let(:context) { {} }

  let(:schema) do
    build_schema(query_type, context_key: ->(context) { context[:current_user_id] })
  end

  let(:query) do
    <<~GQL
      query GetPost($id: ID!) {
        cachedPost(id: $id) {
          id
          title
        }
      }
    GQL
  end

  let(:key) do
    build_key(
      schema,
      path_cache_key: ["cachedPost(id:#{id})"],
      selections_cache_key: { "cachedPost" => %w[id title] }
    )
  end

  include_context "check used key"

  context "when alias is used" do
    # TODO
  end

  context "when fragment has nested selections" do
    let(:query) do
      <<~GQL
        query GetPost($id: ID!) {
          cachedPost(id: $id) {
            id
            title
            author {
              id
              name
            }
          }
        }
      GQL
    end

    let(:key) do
      build_key(
        schema,
        path_cache_key: ["cachedPost(id:#{id})"],
        selections_cache_key: { "cachedPost" => ["id", "title", "author" => %w[id name]] }
      )
    end

    include_context "check used key"
  end

  context "when cached fragment is nested" do
    let(:query) do
      <<~GQL
        query GetPost($id: ID!) {
          post(id: $id) {
            id
            title
            cachedAuthor {
              id
              name
            }
          }
        }
      GQL
    end

    let(:key) do
      build_key(
        schema,
        path_cache_key: ["post(id:#{id})", "cachedAuthor"],
        selections_cache_key: { "cachedAuthor" => %w[id name] }
      )
    end

    include_context "check used key"
  end

  context "when context_key is configured" do
    let(:context) { { current_user_id: 42 } }

    let(:key) do
      build_key(
        schema,
        path_cache_key: ["cachedPost(id:#{id})"],
        selections_cache_key: { "cachedPost" => %w[id title] }
      )
    end

    include_context "check used key"

    context "when context_dependent is passed" do
      let(:context_dependent) { true }
      let(:variables) { { id: id, contextDependent: context_dependent } }

      let(:query) do
        <<~GQL
          query GetPost($id: ID!, $contextDependent: Boolean) {
            cachedPost(id: $id, contextDependent: $contextDependent) {
              id
              title
            }
          }
        GQL
      end

      let(:key) do
        build_key(
          schema,
          path_cache_key: ["cachedPost(context_dependent:#{context_dependent},id:#{id})"],
          selections_cache_key: { "cachedPost" => %w[id title] },
          context_cache_key: 42
        )
      end

      include_context "check used key"

      context "when symbol is passed as context key" do
        let(:schema) do
          build_schema(query_type, context_key: :current_user_id)
        end

        include_context "check used key"
      end
    end

    context "when context_key is passed" do
      let(:context_cache_key) { "13" }
      let(:variables) { { id: id, contextCacheKey: context_cache_key } }

      let(:query) do
        <<~GQL
          query GetPost($id: ID!, $contextCacheKey: String) {
            cachedPost(id: $id, contextCacheKey: $contextCacheKey) {
              id
              title
            }
          }
        GQL
      end

      let(:key) do
        build_key(
          schema,
          path_cache_key: [
            "cachedPost(context_cache_key:#{context_cache_key},id:#{id})"
          ],
          selections_cache_key: { "cachedPost" => %w[id title] },
          context_cache_key: context_cache_key
        )
      end

      include_context "check used key"
    end
  end
end