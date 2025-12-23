require 'monitor'

module DSP
  module DSL
    module LiveLoop
      class << self
        def registry
          @registry ||= {}
        end
        
        def cues
          @cues ||= {}
        end
        
        def lock
          @lock ||= Mutex.new
        end
        
        def stop_all
          lock.synchronize do
            registry.each do |name, thread|
              puts "[DSL] Killing loop: #{name}" if $DEBUG_DSL
              thread.kill rescue nil
            end
            registry.clear
          end
        end
      end

      def live_loop(name, &block)
        LiveLoop.lock.synchronize do
          if LiveLoop.registry[name] && LiveLoop.registry[name].alive?
            LiveLoop.registry[name].kill rescue nil
          end

          LiveLoop.registry[name] = Thread.new do
            puts "[DSL] Starting loop: #{name}" if $DEBUG_DSL
            begin
              loop do
                block.call
              end
            rescue Exception => e
              puts "[DSL] Error in live_loop #{name.inspect}: #{e.message}"
              puts e.backtrace.first(10).join("\n")
            end
          end
        end
      end

      def cue(name)
        puts "[DSL] Cueing: #{name}" if $DEBUG_DSL
        LiveLoop.lock.synchronize do
          LiveLoop.cues[name] ||= ConditionVariable.new
          LiveLoop.cues[name].broadcast
        end
      end

      def sync(name)
        puts "[DSL] Syncing: #{name}..." if $DEBUG_DSL
        cv = nil
        LiveLoop.lock.synchronize do
          cv = (LiveLoop.cues[name] ||= ConditionVariable.new)
          cv.wait(LiveLoop.lock)
        end
        puts "[DSL] Synced: #{name}" if $DEBUG_DSL
      end
    end
  end
end
