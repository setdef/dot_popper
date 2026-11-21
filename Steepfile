# frozen_string_literal: true

# Steep checks the domain's three areas, the use cases between them and
# the screens, and the code they share, against sig/, strictly: a call
# Steep cannot type is an error, not a silent untyped. Steep 2.1 skips
# pattern matching (case/in) entirely, so that is an error here too,
# rather than a part of the rules nobody checks. The presentation, the
# shell and the composition root are not typed yet; the shell would also
# need Lota's signatures. All of Monetization is typed, with the website
# part's license keys and store; the rest of the website part (its
# loader and its prepends on the composition root), the network client's
# network/ and the test build's part are not.
#
# Each area is a target of its own, which sees only its own signatures
# and those of the code the areas share (test/areas_test.rb gives the
# rules, and holds them for the Ruby Steep does not type): a name from
# another area is then an unknown constant or type. Steep gives each
# target the signatures of every other target not marked unreferenced!,
# and a signature file belongs to the first target that lists it, so
# the areas cannot be kept apart in one project that also checks the
# use cases against all of sig/. They are a project of their own, which
# rake steep checks second (STEEP_PROJECT=areas): the shared code's
# target, which every area sees and which sees only itself, and the
# three areas, each unreferenced!, so none sees another.
SHARED = %w[sig/core sig/dot_popper.rbs sig/dot_popper/network.rbs sig/dot_popper/platform.rbs sig/dot_popper/automation.rbs sig/dot_popper/memory_file.rbs].freeze
LIBRARIES = %w[date socket uri].freeze

STRICT = lambda do |hash|
  hash[Steep::Diagnostic::Ruby::UnsupportedSyntax] = :error
end

if ENV["STEEP_PROJECT"] == "areas"
  # The code every area may name, which names none of them.
  target :shared do
    signature(*SHARED)
    LIBRARIES.each { library it }
    check "lib/dot_popper/network.rb", "lib/dot_popper/platform.rb", "lib/dot_popper/automation.rb", "lib/dot_popper/memory_file.rb"
    configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
  end

  # Gameplay and Metagame names nothing of Monetization or Release
  # Engineering.
  target :gameplay do
    signature "sig/dot_popper/gameplay", "gems/dot_popper-gameplay/sig"
    LIBRARIES.each { library it }
    unreferenced!
    check "lib/dot_popper/gameplay/**/*.rb", "gems/dot_popper-gameplay/lib/**/*.rb"
    configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
  end

  # Monetization may hear Gameplay's published events (none of its typed
  # code does yet), and names nothing of Release Engineering, which has no
  # interface at run time.
  target :monetization do
    signature "sig/dot_popper/monetization"
    LIBRARIES.each { library it }
    %w[digest json openssl securerandom].each { library it }
    unreferenced!
    check "lib/dot_popper/monetization/**/*.rb", "lib/dot_popper/website/license_keys.rb", "lib/dot_popper/website/license_keys/*.rb",
          "lib/dot_popper/website/website_store.rb", "lib/dot_popper/apple/receipt.rb", "lib/dot_popper/play/receipt.rb",
          "lib/dot_popper/microsoft/receipt.rb"
    configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
  end

  # Release Engineering names neither area.
  target :release_engineering do
    signature "sig/dot_popper/release_engineering"
    LIBRARIES.each { library it }
    unreferenced!
    check "lib/dot_popper/release_engineering/*.rb"
    configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
  end
else
  # The use cases, which need two areas, and what loads and serves them,
  # against all of sig/.
  target :application do
    signature "sig", "gems/dot_popper-gameplay/sig"
    LIBRARIES.each { library it }
    check "lib/dot_popper.rb", "lib/dot_popper/*.rb", "lib/dot_popper/use_cases/*.rb"
    configure_code_diagnostics(Steep::Diagnostic::Ruby.strict, &STRICT)
  end
end
