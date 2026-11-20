# frozen_string_literal: true

# Steep checks the domain's three areas, the use cases between them and
# the screens, and the code they share, against sig/, strictly: a call
# Steep cannot type is an error, not a silent untyped. Steep 2.1 skips
# pattern matching (case/in) entirely, so that is an error here too,
# rather than a part of the rules nobody checks. The presentation, the
# shell and the composition root are not typed yet; the shell would also
# need Lota's signatures. Nor are Monetization's continuity/ and receipt/,
# the network client's network/, or the test build's part.
#
# Each area is a target of its own, which sees only its own signatures
# and those of what it may name (test/areas_test.rb gives the rules, and
# holds them for the Ruby Steep does not type): a name from another area
# is then an unknown constant or type. A signature file of another area
# that a target loads is a breach of the rules, listed with the step of
# the refactoring list that removes it.
SHARED = %w[sig/core sig/dot_popper.rbs sig/dot_popper/network.rbs sig/dot_popper/platform.rbs sig/dot_popper/automation.rbs].freeze
LIBRARIES = %w[date socket uri].freeze

STRICT = lambda do |hash|
  hash[Steep::Diagnostic::Ruby::UnsupportedSyntax] = :error
end

# Gameplay and Metagame names nothing of Monetization or Release
# Engineering.
target :gameplay do
  signature(*SHARED, "sig/dot_popper/gameplay")
  LIBRARIES.each { library it }
  check "lib/dot_popper/gameplay/**/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
end

# Monetization may hear Gameplay's published events (none of its typed
# code does yet), and names nothing of Release Engineering, which has no
# interface at run time.
target :monetization do
  signature(*SHARED, "sig/dot_popper/monetization",
            # The save file kept in memory is the score record's (step 2.3).
            "sig/dot_popper/gameplay/score_record.rbs", "sig/dot_popper/gameplay/size_class.rbs",
            # The store and the receipts ask the build's channel (steps 5.1
            # to 5.4), and the license whether it keeps keys (6.2).
            "sig/dot_popper/release_engineering/build.rbs")
  LIBRARIES.each { library it }
  check "lib/dot_popper/monetization/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
end

# Release Engineering names neither area.
target :release_engineering do
  signature(*SHARED, "sig/dot_popper/release_engineering")
  LIBRARIES.each { library it }
  check "lib/dot_popper/release_engineering/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
end

# The use cases, which need two areas, and what loads and serves them.
target :application do
  signature "sig"
  LIBRARIES.each { library it }
  check "lib/dot_popper.rb", "lib/dot_popper/*.rb", "lib/dot_popper/use_cases/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
end
