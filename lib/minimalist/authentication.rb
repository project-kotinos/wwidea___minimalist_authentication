module Minimalist
  module Authentication
    GUEST_USER_EMAIL = 'guest'
    
    def self.included( base )
      base.extend(ClassMethods)
      base.class_eval do
        include InstanceMethods
        
        attr_accessor :password
        attr_protected :crypted_password, :salt
        before_save :encrypt_password
        
        validates_presence_of :email
        validates_uniqueness_of :email
        validates_presence_of     :password,                   :if => :active?
        validates_presence_of     :password_confirmation,      :if => :active?
        validates_confirmation_of :password,                   :if => :active?
        validates_length_of       :password, :within => 6..40, :if => :active?
        
        named_scope :active, :conditions => {:active => true}
      end
    end
    
    module ClassMethods
      def authenticate(email, password)
        return if email.blank? || password.blank?
        user = active.first(:conditions => {:email => email})
        return unless user && user.authenticated?(password)
        return user
      end
      
      def secure_digest(*args)
        Digest::SHA1.hexdigest(args.flatten.join('--'))
      end

      def make_token
        secure_digest(Time.now, (1..10).map{ rand.to_s })
      end
      
      def guest
        User.new(:email => GUEST_USER_EMAIL)
      end
    end
    
    module InstanceMethods
      
      def active?
        active
      end
      
      def authenticated?(password)
        crypted_password == encrypt(password)
      end
      
      def logged_in
        self.class.update_all("last_logged_in_at='#{Time.now.to_s(:db)}'", "id=#{self.id}") # use update_all to avoid updated_on trigger
      end
      
      def is_guest?
        email == GUEST_USER_EMAIL
      end
      
      #######
      private
      #######
      
      def encrypt(password)
        self.class.secure_digest(password, salt)
      end
      
      def encrypt_password
        return if password.blank?
        self.salt = self.class.make_token if new_record?
        self.crypted_password = encrypt(password)
      end
    end
  end
end