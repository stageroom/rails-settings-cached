module RailsSettings
  module Adapters
    module Abstract
      module Settings
        extend ActiveSupport::Concern

        module ClassMethods
          # get or set a variable with the variable as the called method
          # rubocop:disable Style/MethodMissing
          def method_missing(method, *args)
            method_name = method.to_s
            super(method, *args)
          rescue NoMethodError
            # set a value for a variable
            if method_name[-1] == '='
              var_name = method_name.sub('=', '')
              value = args.first
              self[var_name] = value
            else
              # retrieve a value
              self[method_name]
            end
          end

          # destroy the specified settings record
          def destroy(var_name)
            var_name = var_name.to_s
            obj = object(var_name)
            raise SettingNotFound, "Setting variable \"#{var_name}\" not found" if obj.nil?

            obj.destroy
            true
          end

          # retrieve all settings as a hash (optionally starting with a given namespace)
          def get_all(starting_with = nil)
            {}.with_indifferent_access
          end

          def where(_sql = nil)
            nil
          end

          # get a setting value by [] notation
          def [](var_name)
            val = object(var_name)
            return val.value if val
            return ::RailsSettings::Default[var_name] if ::RailsSettings::Default.enabled?
          end

          # set a setting value by [] notation
          def []=(var_name, value)
            var_name = var_name.to_s

            record = object(var_name) || thing_scoped.new(var: var_name)
            record.value = value
            record.save!

            value
          end

          def merge!(var_name, hash_value)
            raise ArgumentError unless hash_value.is_a?(Hash)

            old_value = self[var_name] || {}
            raise TypeError, "Existing value is not a hash, can't merge!" unless old_value.is_a?(Hash)

            new_value = old_value.merge(hash_value)
            self[var_name] = new_value if new_value != old_value

            new_value
          end

          def object(_var_name)
            nil
          end

          def thing_scoped
            nil
          end

          def source(filename)
            ::RailsSettings::Default.source(filename)
          end

          def rails_initialized?
            Rails.application && Rails.application.initialized?
          end

          private

          def default_settings(starting_with = nil)
            return {} unless ::RailsSettings::Default.enabled?
            return ::RailsSettings::Default.instance if starting_with.nil?
            ::RailsSettings::Default.instance.select { |key, _| key.to_s.start_with?(starting_with) }
          end
        end

        included do
          belongs_to :thing, polymorphic: true

          class SettingNotFound < RuntimeError; end
        end

        # get the value field, YAML decoded
        def value
          YAML.load(self[:value]) if self[:value].present?
        end

        # set the value field, YAML encoded
        def value=(new_value)
          self[:value] = new_value.to_yaml
        end
      end
    end
  end
end
