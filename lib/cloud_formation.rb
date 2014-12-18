require 'json'

namespace :cloud_formation do

  KEY_MAPPINGS = {
    security_group: {
      name: :group_name,
      group_description: :description
    }
  }

  METHOD_MAPPINGS = {
    security_group: {
      security_group_ingress: :authorize_ingress,
      security_group_egress: :authorize_egress,
      revoke_egress: :revoke_egress
    }
  }

  TYPE_MAPPINGS = {
    'Aws::AutoScaling::LaunchConfiguration' => 'Aws::AutoScaling'
  }

  task create: :connect do
    %w(security_groups/ssh launch_configs/web_servers).each do |filename|
      template = File.read File.join('data', 'cloud_formation', "#{filename}.json.erb")
      json = JSON.parse template
      json.each do |name, params|
        params['Properties']['Name'] = name
        type = params['Type'].gsub(/AWS/, 'Aws')
        modules = type.split('::')
        resource = eval(modules[0..modules.size-2].join('::')+'::Resource').new
        type_key = cf_to_sdk modules.last
        type = TYPE_MAPPINGS[type] || type

        params = remap type_key, params
        properties = params[:properties]
        log properties.inspect

        method_calls = [].tap do |calls|
          METHOD_MAPPINGS[type_key] && METHOD_MAPPINGS[type_key].each do |key, method|
            options = properties.delete key
            next unless options
            Array(options).each do |arg|
              calls << [method, arg]
            end
          end
        end


        # test -- delete
        if type_key == :security_group
          resource.security_groups.each do |sg|
            sg.delete unless sg.group_name == 'default'
          end
        end

        obj = resource.client.send("create_#{type_key}", properties)

        method_calls.each do |method, options|
          log method
          log options.inspect
          obj.send method, options
        end
      end
    end


  end
end

def remap type, hash
  return hash unless hash.is_a? Hash
  {}.tap do |result|
    hash.each do |key, value|
      case value
      when Array then value.map!{ |val| val.is_a?(Hash) ? remap(type, val) : val }
      when Hash then value = remap(type, value)
      end
      key = cf_to_sdk(key)
      key = (KEY_MAPPINGS[type] && KEY_MAPPINGS[type][key]) || key
      result[key] = value
    end
  end
end

def cf_to_sdk key
  key.gsub(/[A-Z](?![A-Z])/){ |char| "_#{char}" }.sub(/^_/, '').downcase.to_sym
end

