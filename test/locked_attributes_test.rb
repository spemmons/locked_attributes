require 'test_helper'

class LockedAttributesTest < ActiveSupport::TestCase

  ActiveRecord::Base.connection.drop_table :unlocked_attribute_testers if ActiveRecord::Base.connection.table_exists?(:unlocked_attribute_testers)
  ActiveRecord::Base.connection.create_table :unlocked_attribute_testers do |t|
    t.integer :test_unlocked
  end

  ActiveRecord::Base.connection.drop_table :locked_attribute_testers if ActiveRecord::Base.connection.table_exists?(:locked_attribute_testers)
  ActiveRecord::Base.connection.create_table :locked_attribute_testers do |t|
    t.integer :test_unlocked
    t.integer :test_always
    t.integer :test_optional
    t.integer :test_optional_locked
  end

  class UnlockedAttributeTester < ActiveRecord::Base; end

  class LockedAttributeTester < ActiveRecord::Base
    lock_attributes :test_always,:test_optional
  end

  test 'all methods work when lock_attributes is not used' do
    assert_equal [],UnlockedAttributeTester.locked_attribute_names
    assert_equal [],UnlockedAttributeTester.always_locked_attribute_names
    assert_equal [],UnlockedAttributeTester.optionally_locked_attribute_names
    assert_equal [],UnlockedAttributeTester.locking_attribute_names

    assert !UnlockedAttributeTester.new.is_attribute_locked?(:test_unlocked) 
  end

  test 'trap exception if table does not exist' do # NOTE -- this exists to ensure that an exception is caught for full coverage
    class MissingTableTester < ActiveRecord::Base
      lock_attributes :test_one
      lock_attributes :test_two
    end

    assert_equal ['test_one','test_two'],MissingTableTester.locked_attribute_names
  end

  test 'locked attributes can be inquired' do
    assert_equal ['test_always','test_optional'],LockedAttributeTester.locked_attribute_names
    assert_equal ['test_always'],LockedAttributeTester.always_locked_attribute_names
    assert_equal ['test_optional'],LockedAttributeTester.optionally_locked_attribute_names
    assert_equal ['test_optional_locked'],LockedAttributeTester.locking_attribute_names
  end

  test "the 'attributes_locked?' and 'unlock_attributes' methods work properly together" do

    tester = LockedAttributeTester.new
    assert !tester.attributes_unlocked?
    tester.unlock_attributes do | value |
      assert tester.attributes_unlocked?
      assert_equal tester,value
    end

    error_message = 'Check that unlock status is properly reset'
    begin
      tester.unlock_attributes do
        raise error_message
      end
      assert false
    rescue
      assert_equal error_message,$!.to_s
    end
    assert !tester.attributes_unlocked?

    assert_raises(LockedAttributes::NestedUnlocks) do
      tester.unlock_attributes do
        assert true
        tester.unlock_attributes do
          assert false
        end
        assert false
      end
    end

  end

  test 'no locking changes do not complain' do
    test_attribute_scenario(
      {:test_unlocked => 1},
      {:test_unlocked => 2},
      nil)
  end

  test 'partially locked attributes with nil' do
    test_attribute_scenario(
      {:test_unlocked => 1,:test_always => 2,:test_optional => 3},
      {:test_unlocked => 2,:test_always => 3,:test_optional => 4},
      [['test_always','is locked']])
  end

  test 'partially locked attributes with false' do
    test_attribute_scenario(
      {:test_unlocked => 1,:test_always => 2,:test_optional => 3,:test_optional_locked => false},
      {:test_unlocked => 2,:test_always => 3,:test_optional => 4},
      [['test_always','is locked']])
  end

  test 'fully locked attributes' do
    test_attribute_scenario(
      {:test_unlocked => 1,:test_always => 2,:test_optional => 3,:test_optional_locked => true},
      {:test_unlocked => 2,:test_always => 3,:test_optional => 4},
      [['test_always','is locked'],['test_optional','is locked']])
  end

  test 'optional locks can only be changed inside unlock_attributes' do
    test_attribute_scenario(
      {:test_optional_locked => true},
      {:test_optional_locked => false},
      [['test_optional_locked','is locked']])
  end

  def test_attribute_scenario(starters,changes,errors)
    tester = LockedAttributeTester.create!(starters)

    assert_equal false,tester.is_attribute_locked?(:test_unlocked)
    assert_equal true,tester.is_attribute_locked?(:test_always)
    assert_equal !starters[:test_optional_locked],!tester.is_attribute_locked?(:test_optional)

    assert_equal false,tester.is_attribute_locked?('test_unlocked')
    assert_equal true,tester.is_attribute_locked?('test_always')
    assert_equal !starters[:test_optional_locked],!tester.is_attribute_locked?('test_optional')

    if tester.update_attributes(changes)
      assert_nil errors
    else
      change_keys = changes.keys.collect{| key | key.to_s}.sort

      assert_equal change_keys,tester.changes.keys.sort
      assert_equal errors,tester.errors.to_a

      tester.unlock_attributes do
        assert_equal change_keys,tester.changes.keys.sort
        assert tester.save
      end
    end
  end

end

