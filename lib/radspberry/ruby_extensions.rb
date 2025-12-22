module ArrayExtensions

  def to_v
    Vector[*self]
  end

  def tick_sum inp=0.0
    inject( inp ){|sum,p| sum + p.tick }
  end
  
  def ticks_sum samples, inp=nil # vector manipulation
    inp ||= Vector.zeros(samples)
    inject( inp ){|sum,p| sum + p.ticks(samples) }
  end
  
  module ClassMethods
    def full_of(val,count)
      [].fill(val,0...count)
    end

    def zeros count
      full_of(0,count)
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

end
Array.send :include, ArrayExtensions


module VectorExtensions
  def full_of(val,count)
    Array.full_of(val,count).to_v
  end

  def zeros count
    full_of(0.0,count)
  end

  def to_v
    self
  end
end
Vector.send :extend, VectorExtensions
Vector.send :include, VectorExtensions


module ModuleExtensions  
  
  def param_accessor symbol, opts={}, &block
    opts = { :range => opts } if opts.is_a?(Range)
    opts.reverse_merge! :range => (0..1)
    var = nil
    if d = opts[:delegate]
      d = "@#{d}" if d.is_a?(Symbol)      
      d = "#{d}.#{symbol}" unless d =~ /\./
      d,s = d.split(".")
      var = "#{d} && #{d}.#{s}"  # try first
    else
      var = symbol
      var = "@#{var}" if var.is_a?(Symbol)
    end

    ## define getter
    if opts[:default]
      module_eval "def #{symbol}() #{var} || #{opts[:default]}; end"
    else
      module_eval "def #{symbol}() #{var}; end"
    end

    ## define setter
    if opts[:range]
      min,max = opts[:range].first.to_f, opts[:range].last.to_f
      module_eval <<-STR
        def #{symbol}=(val)
          #{var} = DSP.clamp(val,#{min},#{max})
          #{"after_set_#{symbol}" if opts[:after_set]}
        end
      STR
      define_method "after_set_#{symbol}", opts[:after_set] if opts[:after_set]
    else
      module_eval "def #{symbol}=(val) #{var} = val; end"
    end
  end
end

Module.send :include, ModuleExtensions
