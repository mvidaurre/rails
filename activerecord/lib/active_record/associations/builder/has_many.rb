require 'active_support/core_ext/object/inclusion'

module ActiveRecord::Associations::Builder
  class HasMany < CollectionAssociation #:nodoc:
    self.macro = :has_many

    self.valid_options += [:primary_key, :dependent, :as, :through, :source, :source_type, :inverse_of]

    def build
      reflection = super
      configure_dependency
      reflection
    end

    private

      def configure_dependency
        if options[:dependent]
          unless options[:dependent].in?([:destroy, :delete_all, :nullify, :restrict])
            raise ArgumentError, "The :dependent option expects either :destroy, :delete_all, " \
                                 ":nullify or :restrict (#{options[:dependent].inspect})"
          end

          dependent_restrict_deprecation_warning if options[:dependent] == :restrict
          send("define_#{options[:dependent]}_dependency_method")
          model.before_destroy dependency_method_name
        end
      end

      def define_destroy_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).each do |o|
            # No point in executing the counter update since we're going to destroy the parent anyway
            o.mark_for_destruction
          end

          send(name).delete_all
        end
      end

      def define_delete_all_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).delete_all_on_destroy
        end
      end

      def define_nullify_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).delete_all
        end
      end

      def define_restrict_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          if send(name).exists?
            if dependent_restrict_raises?
              raise ActiveRecord::DeleteRestrictionError.new(name)
            else
              errors.add(:base, :restrict_dependent_destroy, :model => name)
              return false
            end
          end
        end
      end

      def dependency_method_name
        "has_many_dependent_for_#{name}"
      end
  end
end
