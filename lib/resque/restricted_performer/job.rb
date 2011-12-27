module Resque
  class Job
    # alias_method :original_reserve, :reserve
    
    # This callback clears the job off the queue and then removes the lock. Doing it in this
    # order avoids the job being picked up by another worker, which could happen if the lock was
    # removed first, but does mean we need to get the queue name from the lock first, as the args 
    # submitted don't contain the queue name
    def self.after_perform_clear_performed_lock(args)
      lock_name = performer_lock_name(args)
      full_lock_name = "performer_lock:#{lock_name}"
      queue_name = redis.get(full_lock_name) # get queue name
      redis.lrem("queue:#{queue_name}", 1, encode(args)) # remove from queue
      redis.del(full_lock_name) # release lock
    end
    
    def self.next_unlocked(queue)
      potential_jobs = Resque.peek(queue, 0, 10)
      next_job = potential_jobs.detect{ |pj| lock_if_free!(pj, queue) }
    end
    
    def self.reserve(queue)
      return unless payload = next_unlocked(queue)
      new(queue, payload)
    end
    
    def self.lock_if_free!(potential_job, queue_name)
      lock_name = performer_lock_name(potential_job)
      redis.setnx("performer_lock:#{lock_name}", queue_name)
    end
    
    def self.performer_lock_name(job_attributes)
      obj_klass = constantize(job_attributes['class'])
      if obj_klass.respond_to?('performer_lock_name') 
        obj_klass.performer_lock_name(job_attributes['args'])
      else
        "#{job_attributes['class']}_#{job_attributes['args'].join('_')}"
      end
    end      
  end
end