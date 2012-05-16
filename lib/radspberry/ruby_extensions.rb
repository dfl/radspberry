module ArrayExtensions
  def full_of(val,num)
    [].fill(val,0...num)
  end

  def zeros num
    full_of(0,num)
  end
end
Array.send :extend, ArrayExtensions

module ModuleExtensions
  
  def param_accessor symbol, opts={}
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
      module_eval "def #{symbol}() #{var} || #{opts[:default]}; end"  # TODO allow Proc.call(self) ?
    else
      module_eval "def #{symbol}() #{var}; end"
    end

    ## define setter
    if opts[:range]
      min,max = opts[:range].first.to_f, opts[:range].last.to_f
      module_eval "def #{symbol}=(val) #{var} = DSP.clamp(val,#{min},#{max}); end"
    else
      module_eval "def #{symbol}=(val) #{var} = val; end"
    end
  end
end
Module.send :include, ModuleExtensions
