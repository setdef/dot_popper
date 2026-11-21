# frozen_string_literal: true

# A stand-in for a computer's store helper (macos/store/main.swift,
# windows/store/dot_popper_store.c), for the store contract: it takes one
# dotpopper-store: URL, answers "loading" or "working" at once and the
# outcome once the test has read that one (it makes read-N in +folder+
# for request N), each the whole state followed by an empty line, on its
# standard output, and exits. What the store knows lives in
# +folder+ (owned, and whether the price was asked), as a store's own
# record would. Its receipts are the test build's, as the fake store's
# are. Run as:
#
#   ruby -Ilib -Igems/dot_popper-monetization/lib store_helper_stand_in.rb FOLDER FAILS URL
require "dot_popper/monetization/receipt"
require "dot_popper/play/receipt"
require "dot_popper/test_build/receipt_test_key"

folder, fails, url = ARGV
fails = nil if fails.to_s.empty?
action = url[%r{://(\w+)}, 1]
number = url[/[?&]n=(\d+)/, 1]
file = url[/[?&]file=([^&]*)/, 1]
abort "answers go down the pipe" unless file == "-"

owned_at = File.join(folder, "owned")
priced_at = File.join(folder, "priced")
owned = -> { File.exist?(owned_at) }
price = -> { File.exist?(priced_at) ? "$1.99" : "" }

answer = lambda do |state|
  receipt = owned.call ? "receipt=#{DotPopper::Monetization::Receipt.issue}\n" : ""
  $stdout.write("answer=#{number}\nowned=#{owned.call ? 1 : 0}\nstate=#{state}\nprice=#{price.call}\n#{receipt}\n")
  $stdout.flush
end

answer.call(action == "open" ? "loading" : "working")
# The outcome waits for the test to have read the answer before it, so
# however slow the machine, no read skips it. A test that never reads
# leaves the stand-in waiting until its folder goes, or a minute.
read_at = File.join(folder, "read-#{number}")
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
until File.exist?(read_at)
  exit unless Dir.exist?(folder) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline

  sleep 0.005
end

outcome = if fails == "unavailable" then "unavailable"
          else
            case action
            when "open"
              File.write(priced_at, "")
              "ready"
            when "buy"
              if price.call.empty? then "failed"
              elsif fails then fails
              else
                File.write(owned_at, "")
                "ready"
              end
            when "restore"
              if %w[failed canceled].include?(fails) then fails
              else owned.call ? "restored" : "none"
              end
            else "failed"
            end
          end
answer.call(outcome)
