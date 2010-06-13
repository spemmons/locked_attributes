module LockedAttributes

  class NestedUnlocks < Exception; end

  module ClassMethods

    # return the list of all locked attribute names
    def locked_attribute_names
      []
    end

    # return the list of attributes that controller the locking status of "optionally" locked attributes
    def locking_attribute_names
      []
    end

    # return the list of attributes that are "always" locked (e.g., have no "..._locked" companion attribute)
    def always_locked_attribute_names
      []
    end

    # return the list of attributes that are "optionally" locked (e.g., have a "..._locked" companion attribute)
    def optionally_locked_attribute_names
      []
    end

    # declare which attribute names should be "locked"; any attributes specified will also have a companion method ending with "_locked?"
    def lock_attributes(*attribute_names_to_lock)

      # TODO figure out (if possible) how to make the writer private so that only 'lock_attributes' can be used
      cattr_accessor :locked_attribute_names,:locking_attribute_names,:always_locked_attribute_names,:optionally_locked_attribute_names

      self.locked_attribute_names ||= []
      self.locking_attribute_names ||= []
      self.always_locked_attribute_names ||= []
      self.optionally_locked_attribute_names ||= []

      self.locked_attribute_names += attribute_names_to_lock.collect{| name | name.to_s}

      begin
        self.locked_attribute_names.each do | attribute_name |
          if self.column_names.include?(locked_attribute_name = "#{attribute_name}_locked")
            self.locking_attribute_names << locked_attribute_name
            self.optionally_locked_attribute_names << attribute_name
          else
            self.always_locked_attribute_names << attribute_name
            define_method("#{locked_attribute_name}?".to_sym){true}
          end
        end
      rescue ActiveRecord::StatementInvalid # NOTE: the class can be loaded during a migration before the table exists (later it should be fine)
        puts "NOTE: class #{self.name} doesn't yet have a defined table"
      end

      validates_each self.locked_attribute_names do | record,attribute_name |
        next if record.new_record? or record.attributes_unlocked?
        next unless record.changes[attribute_name = attribute_name.to_s]
        next unless record.send("#{attribute_name}_locked?")

        record.errors.add(attribute_name,'is locked')
      end

      validates_each self.locking_attribute_names do | record,attribute_name |
        next if record.new_record? or record.attributes_unlocked?
        next unless record.changes[attribute_name = attribute_name.to_s]

        record.errors.add(attribute_name,'is locked')
      end
    end

  end

  def self.included(klass)
    klass.extend ClassMethods
  end

  # return whether or not the given attribute is locked or not
  def is_attribute_locked?(attribute_name)
    attribute_name = attribute_name.to_s
    self.class.locked_attribute_names.include?(attribute_name) && send("#{attribute_name}_locked?")
  end

  # return whether or not the object is currently unlocked (e.g., inside an enclosing "unlock_attributes") block
  def attributes_unlocked?
    @attributes_unlocked
  end

  # turn off locking during the execution of the given block
  def unlock_attributes(&block)
    raise NestedUnlocks if @attributes_unlocked
    @attributes_unlocked = true
    block.call(self)
  ensure
    @attributes_unlocked = false
  end

end
