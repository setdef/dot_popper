# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What the microsoft part answers, in a build that carries it: the
      # Microsoft Store's build trusts Windows' word alone, which comes only
      # down the store helper's pipe (Root.receipt_trust).
      module MicrosoftChoices
        def receipt_trust(settings)
          settings.channel == ReleaseEngineering::Build::MICROSOFT_STORE ? Monetization::Receipt::MICROSOFT_STORE : super
        end
      end
      singleton_class.prepend(MicrosoftChoices)
    end
  end
end
