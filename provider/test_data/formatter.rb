# Copyright 2017 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Provider
  # Responsible for creating the various parts of autogenerated unit tests.
  module TestData
    # Base class for builing out unit test manifests.
    # rubocop:disable Metrics/ClassLength
    class Formatter
      def initialize(datagen)
        @datagen = datagen
      end

      # Generates a manifest / recipe for a DependencyGraph worth of resources.
      # Requires:
      #   collector - The DependencyGraph of resources
      #   base_name - The name of the base object.
      #   kind - :name vs :title
      #   extra - extra attributes
      def generate_all_objects(collector, base_name, kind, extra)
        collector.map do |object|
          if object.object.name == base_name
            generate_object(object.object, "title#{object.seed}", kind,
                            object.seed, extra)
          else
            generate_ref(object.object, object.seed)
          end
        end
      end

      # Generates a resource block for a resource ref.
      # Requires the ResourceRef and an index.
      def generate_ref(_ref, _index)
        raise 'Implement generate_ref to output a formatted block'
      end

      private

      # Outputs an entire block of testing data
      def generate_object(_object, _title, _kind, _seed, _extra)
        raise 'Implement generate to output a formatted block'
      end

      def emit_manifest_block(_props, _seed, _extra, _ctx)
        raise 'Implement emit_manifest_block to output formatetd properties'
      end

      def formatter(_type, _value)
        raise 'Implement the formatter to shape final output.'
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      # prop_name_method is a method that returns the proper name of the object
      # rref_value: If true, return the value being exported by the ref'd block
      #             If false, return the title of the block being referenced
      def emit_manifest_assign(prop, seed, ctx, prop_name_method,
                               rref_value = false)
        name = prop_name_method.call
        type = prop.class
        if prop.is_a?(Api::Type::Primitive)
          [name, formatter(type, @datagen.value(type, prop, seed))]
        elsif prop.is_a?(Api::Type::Array)
          emit_manifest_array(type, prop, seed, ctx, prop_name_method)
        elsif prop.is_a?(Api::Type::NestedObject)
          [name, formatter(type, emit_nested(prop, seed, ctx))]
        elsif prop.is_a?(Api::Type::ResourceRef)
          if rref_value
            [name, formatter(type, emit_resource_value(prop, seed, ctx))]
          else
            [name, formatter(type, emit_resource(prop, seed, ctx))]
          end
        elsif prop.is_a?(Api::Type::NameValues)
          [name, formatter(type, emit_namevalues(prop, seed, ctx))]
        else
          raise "Unknown property type: #{prop.class}"
        end
      end

      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity
      # prop_name_method should be a valid method on a Api::Type::*
      # Typically, this will be "out_name" or "field_name"
      def emit_manifest_array(type, prop, seed, ctx, prop_name_method)
        subtype = prop.item_type_class
        name = prop_name_method.call
        [name,
         if prop.item_type.is_a?(Api::Type::NestedObject)
           formatter(
             type,
             @datagen
               .value([type, subtype], prop, seed)
               .call do |index|
                 formatter(subtype,
                           emit_nested(prop.item_type, seed + index - 1, ctx))
               end
           )
         else
           formatter([type, subtype], @datagen.value([type, subtype],
                                                     prop, seed))
         end]
      end
      # rubocop:enable Metrics/MethodLength

      def emit_nested(prop, seed, ctx)
        emit_manifest_block(prop.properties, seed, {}, ctx)
      end

      # Returns the title of the block being referenced
      def emit_resource(prop, seed, _ctx)
        name = Google::StringUtils.underscore(prop.resource_ref.name)
        "resource(#{name},#{seed % MAX_ARRAY_SIZE})"
      end

      # Returns the value being exported by a ResourceRef
      def emit_resource_value(prop, seed, _ctx)
        @datagen.value(prop.property.class, prop.property,
                       seed % MAX_ARRAY_SIZE)
      end

      def emit_namevalues(prop, seed, _ctx)
        values = @datagen.value(prop.class, prop, seed)
        max_key = values.max_by { |k, _v| k }.first.length
        values.map do |k, v|
          formatted = v

          # Non numbers should be in quotes
          formatted = "'#{v}'" unless v.is_a?(::Integer) || v.is_a?(::Float)
          [quote_string(k), ' ' * [0, max_key - k.length].max, ' => ',
           formatted].join
        end
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def select_properties(props, kind, extra)
        name_props = props.select { |p| p.name == 'name' }
        props = props.reject(&:output)

        props = props.select { |p| p.required || p.name == 'name' } \
          if (extra.key?(:ensure) && extra[:ensure].to_sym == :absent) ||
             (extra.key?(:action) && extra[:action] == ':delete')

        if kind == :resource
          props = props.select { |p| p.required || p.name == 'name' }
          # Name property may be output only, but is still needed.
          if props.select { |p| p.name == 'name' }.empty?
            props << name_props[0] unless name_props.empty?
          end
          props
        elsif kind == :title
          props.reject { |p| p.name == 'name' }
        else
          props
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize
    end

    def quote_string(s)
      @provider.quote_string(s)
    end
    # rubocop:enable Metrics/ClassLength
  end
end
