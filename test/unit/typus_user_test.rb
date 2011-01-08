require "test_helper"

class TypusUserTest < ActiveSupport::TestCase

  [ %Q(this_is_chelm@example.com\n<script>location.href="http://spammersite.com"</script>),
    'admin',
    'TEST@EXAMPLE.COM',
    'test@example',
    'test@example.c',
    'testexample.com' ].each do |value|
    should_not allow_value(value).for(:email)
  end

  [ 'test+filter@example.com',
    'test.filter@example.com',
    'test@example.co.uk',
    'test@example.es' ].each do |value|
    should allow_value(value).for(:email)
  end

  should validate_presence_of :email
  should validate_presence_of :role

  should_not allow_mass_assignment_of :status

  should ensure_length_of(:password).is_at_least(6).is_at_most(40)

  should "verify columns" do
    expected = %w(id first_name last_name email role status salt crypted_password token preferences created_at updated_at).sort
    output = TypusUser.columns.map(&:name).sort
    assert_equal expected, output
  end

  context "generate" do

    should "not be valid if email is not passed" do
      assert TypusUser.generate.invalid?
    end

    should "be valid when email is passed" do
      options = { :email => 'demo@example.com' }
      assert TypusUser.generate(options).valid?
    end

    should "accept password" do
      options = { :email => 'demo@example.com', :password => 'XXXXXXXX' }
      assert TypusUser.generate(options).valid?
    end

    should "accept role" do
      options = { :email => 'demo@example.com', :role => 'admin' }
      assert TypusUser.generate(options).valid?
    end

  end

  context "TypusUser" do

    setup do
      @typus_user = Factory(:typus_user)
    end

    should "return email" do
      assert_equal @typus_user.email, @typus_user.name
    end

    should "return first_name" do
      @typus_user.first_name = "John"
      assert_equal "John", @typus_user.name
    end

    should "return last_name" do
      @typus_user.last_name = "Locke"
      assert_equal "Locke", @typus_user.name
    end

    should "return name when first_name and last_name are set" do
      @typus_user.first_name, @typus_user.last_name = "John", "Locke"
      assert_equal "John Locke", @typus_user.name
    end

    should "return name when first_name and last_name are set to nil" do
      @typus_user.first_name, @typus_user.last_name = nil
      assert_equal @typus_user.email, @typus_user.name
    end

    should "verify salt never changes" do
      expected = @typus_user.salt
      @typus_user.update_attributes(:password => '11111111', :password_confirmation => '11111111')
      assert_equal expected, @typus_user.salt
    end

    should "verify authenticated? returns true or false" do
      assert @typus_user.authenticated?('12345678')
      assert !@typus_user.authenticated?('87654321')
    end

    should "verify can? accepts a Class" do
      assert @typus_user.can?('delete', TypusUser)
    end

    should "verify can? accepts an String" do
      assert @typus_user.can?('delete', 'TypusUser')
    end

    should "verify cannot? acccepts a Class" do
      assert !@typus_user.cannot?('delete', TypusUser)
    end

    should "verify cannot? acccepts an String" do
      assert !@typus_user.cannot?('delete', 'TypusUser')
    end

    should "verify preferences are nil by default" do
      assert @typus_user.preferences.nil?
    end

    should "return default_locale when no preferences are set" do
      assert_equal :en, @typus_user.locale
    end

    should "be able to set a locale" do
      @typus_user.locale = :jp

      expected = {:locale => :jp}
      assert_equal expected, @typus_user.preferences
      assert_equal :jp, @typus_user.locale
    end

    should "be able to set preferences" do
      @typus_user.preferences = {:chunky => "bacon"}
      assert @typus_user.preferences.present?
    end

    should "set locale preference without overriding previously set preferences" do
      @typus_user.preferences = {:chunky => "bacon"}
      @typus_user.locale = :jp

      expected = {:locale => :jp, :chunky => "bacon"}
      assert_equal expected, @typus_user.preferences
    end

    should "have a token set after creation" do
      assert @typus_user.token.present?
      assert @typus_user.token.size.eql?(12)
    end

  end

  context "Admin Role" do

    setup do
      @typus_user = Factory(:typus_user)
    end

    should "respond true and false to is_root? and is_not_root?" do
      assert @typus_user.is_root?
      assert !@typus_user.is_not_root?
    end

    should "get a list of all applications" do
      assert_equal Typus.applications, @typus_user.applications
    end

    should "get a list of application resources for CRUD Extended application" do
      expected = ["Asset", "Category", "Comment", "Page", "Post"]
      assert_equal expected, @typus_user.application("CRUD Extended")
    end

    should "get a list of application resources for Admin application" do
      assert_equal %w(TypusUser), @typus_user.application("Admin")
    end

  end

  context "Editor Role" do

    setup do
      @typus_user = Factory(:typus_user, :role => "editor")
    end

    should "respond true and false to is_no_root? and is_root?" do
      assert @typus_user.is_not_root?
      assert !@typus_user.is_root?
    end

    should "get a list of all applications" do
      expected = ["Admin", "CRUD Extended"]
      assert_equal expected, @typus_user.applications
    end

    should "get a list of application resources" do
      assert_equal %w(Category Comment Post), @typus_user.application("CRUD Extended")
      assert_equal %w(TypusUser), @typus_user.application("Admin")
    end

  end

end
