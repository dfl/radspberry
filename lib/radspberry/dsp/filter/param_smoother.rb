# Exponential parameter smoother wrapper

module DSP
  class ParamSmoother < Processor
    include Math

    def initialize(processor, params: [:freq], tau: 0.01)
      @processor = processor
      @params = params
      @tau = tau
      @alpha = 1.0 - exp(-1.0 / (tau * srate))

      @current = {}
      @target = {}

      @params.each do |param|
        if @processor.respond_to?(param)
          value = @processor.send(param)
          @current[param] = value.to_f
          @target[param] = value.to_f
        end
      end
    end

    def tau=(tau)
      @tau = tau
      @alpha = 1.0 - exp(-1.0 / (tau * srate))
    end

    def smooth_time_ms=(ms)
      self.tau = ms * 1e-3
    end

    def method_missing(method, *args)
      param_name = method.to_s.chomp('=').to_sym

      if method.to_s.end_with?('=') && @params.include?(param_name)
        @target[param_name] = args.first.to_f
      elsif @params.include?(method)
        @target[method]
      else
        @processor.send(method, *args)
      end
    end

    def respond_to_missing?(method, include_private = false)
      param_name = method.to_s.chomp('=').to_sym
      @params.include?(param_name) || @processor.respond_to?(method, include_private)
    end

    def tick(input)
      @params.each do |param|
        if @current[param] != @target[param]
          @current[param] += @alpha * (@target[param] - @current[param])

          if @processor.respond_to?("#{param}=")
            @processor.send("#{param}=", @current[param])
          end
        end
      end

      @processor.tick(input)
    end

    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
    end

    attr_reader :processor
  end
end
