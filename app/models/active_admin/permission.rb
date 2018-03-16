module ActiveAdmin
  class Permission < ActiveRecord::Base
    self.table_name = :active_admin_permissions

    role_based_authorizable

    enum state: { cannot: 0, can: 1 }

    belongs_to :managed_resource

    delegate :class_name, :action, :name, :const, :active?, :for_active_admin_page?, to: :managed_resource
    delegate :clear_cache, to: :class

    after_update :clear_cache

    with_options presence: true do
      validate :managed_resource_id
      validate :role
      validate :state
    end

    validates :managed_resource_id, uniqueness: { scope: [:role] }

    def to_condition
      [].tap do |cond|
        cond << state
        cond << action.to_sym
        cond << const
        cond << { name: name } if for_active_admin_page?
      end
    end

    class << self
      def update_all_from_managed_resources(managed_resources)
        managed_resources.each do |managed_resource|
          manageable_roles.values.each do |value_of_role|
            find_or_create_by!(managed_resource_id: managed_resource.id, role: value_of_role) do |permission|
              permission.state = default_state
            end
          end
        end
      end

      def indexed_cache
        @_indexed_cache ||= eager_load(:managed_resource).all.group_by(&:role)
      end

      def clear_cache
        @_indexed_cache = nil
      end

      private

      def default_state
        @_default_state ||= ::ActiveAdminRole.config.default_state
      end
    end
  end
end
