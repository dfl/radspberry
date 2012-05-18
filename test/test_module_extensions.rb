require "test/unit"
require "radspberry/ruby_extensions"

require 'active_support/core_ext/hash/reverse_merge'

class TestModuleExtensions < Test::Unit::TestCase
  
  class Tester
    param_accessor :spread, :default => 0.5, :after_set => Proc.new{ @bang = true }
    attr_accessor :bang

    def initialize
      @bang = false
    end
  end    

  def test_param_accessor_after_set
    t = Tester.new
    assert_equal false, t.bang
    t.spread = 10
    assert_equal true, t.bang
    assert_equal 1.0, t.spread
  end
  
end


