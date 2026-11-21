# frozen_string_literal: true

require "test_helper"

# Every automated run stays off the internet: what happens in production
# can never change a test's result. The guard's own tests are the shared
# gem's (gems/dot_popper-shared/test/dot_popper/automation_test.rb); this
# one names Monetization's request to setdef's server.
class AutomationTest < Minitest::Test
  Automation = DotPopper::Automation

  def test_the_link_cannot_reach_the_real_server_from_a_test
    link = DotPopper::Network::Link.new(DotPopper::Network::Server::SERVER_URL)
    job = DotPopper::Network::Job.of(DotPopper::Monetization::Continuity::SetdefServer::REQUESTS.fetch(:proof), query: { nonce: "00" })
    assert_raises(Automation::OutsideConnection) { link.call(job, nil) }
  end
end
