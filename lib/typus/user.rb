require 'bcrypt'

module Typus

  module EnableAsTypusUser

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def enable_as_typus_user

        extend ClassMethodsMixin

        attr_reader   :password
        attr_accessor :password_confirmation

        attr_protected :crypted_password if respond_to?(:attr_protected)
        attr_protected :status

        validates :crypted_password, :presence => true
        validates :email, :presence => true, :uniqueness => true, :format => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/ }
        validates :password, :confirmation => true
        validates :role, :presence => true

        validates_length_of :password, :within => 6..40, :if => :password_required?

        before_create :initialize_token

        serialize :preferences

        include InstanceMethods

        scope :active, where(:status => true)

      end

    end

    module ClassMethodsMixin

      def generate(*args)
        options = args.extract_options!

        options[:password] ||= ActiveSupport::SecureRandom.hex(4)
        options[:role] ||= Typus.master_role

        new :email => options[:email],
            :password => options[:password],
            :role => options[:role],
            :preferences => { :locale => ::I18n.default_locale.to_s }
      end

    end

    module InstanceMethods

      def name
        full_name = [first_name, last_name].delete_if { |s| s.blank? }
        full_name.any? ? full_name.join(" ") : email
      end

      def authenticate(unencrypted_password)
        BCrypt::Password.new(crypted_password) == unencrypted_password ? self : false
      end

      def resources
        Typus::Configuration.roles[role].compact
      end

      def applications
        Typus.applications.delete_if { |a| application(a).empty? }
      end

      def application(name)
        Typus.application(name).delete_if { |r| !resources.keys.include?(r) }
      end

      def can?(action, resource, options = {})
        resource = resource.model_name if resource.is_a?(Class)

        return false if !resources.include?(resource)
        return true if resources[resource].include?("all")

        action = options[:special] ? action : action.acl_action_mapper

        resources[resource].extract_settings.include?(action)
      end

      def cannot?(*args)
        !can?(*args)
      end

      def is_root?
        role == Typus.master_role
      end

      def is_not_root?
        !is_root?
      end

      def locale
        (preferences && preferences[:locale]) ? preferences[:locale] : ::I18n.default_locale
      end

      def locale=(locale)
        options = { :locale => locale }
        self.preferences ||= {}
        self.preferences[:locale] = locale
      end

      def password=(unencrypted_password)
        @password = unencrypted_password
        self.crypted_password = BCrypt::Password.create(unencrypted_password)
      end

      protected

      def initialize_token
        self.token = ActiveSupport::SecureRandom.hex
        self.salt = ActiveSupport::SecureRandom.hex
      end

      def password_required?
        crypted_password.blank? || password.present?
      end

    end

  end

end

ActiveRecord::Base.send :include, Typus::EnableAsTypusUser
