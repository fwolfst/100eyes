# frozen_string_literal: true

module ChatMessages
  class ChatMessages < ApplicationComponent
    def initialize(messages:, **)
      super
      @messages = messages
    end

    private

    attr_reader :messages
  end
end
