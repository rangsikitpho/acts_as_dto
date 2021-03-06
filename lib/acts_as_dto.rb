module ActsAsDto
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    
    VALID_DTO_OPTIONS = [:class_name, :method_name, :xml_name]
    
    def acts_as_dto(*args)      
      options = args.extract_options!      
      options.assert_valid_keys(VALID_DTO_OPTIONS)      

      field_function_map = args.inject(Hash.new) { |m,arg| arg.is_a?(Array) ? m[arg[0]] = arg[1] : m[arg] = arg; m }
      
      dto_class_name = options.fetch(:class_name, self.to_s + "DataTransferObject")
      dto_method_name = options.fetch(:method_name, "dto")
      dto_xml_name = options.fetch(:xml_name, dto_class_name.underscore.gsub('/','_'))
      
      Object.module_eval(<<-EVAL, __FILE__, __LINE__)     
        class #{dto_class_name}
          include ActsAsDto::Dto
          FIELD_MAP = { #{field_function_map.map{ |field,func| ":#{field} => :#{func}" }.join(",") } }
          attr_accessor *(FIELD_MAP.keys)
          
          def self.xml_name
            "#{dto_xml_name}"
          end
          
          def initialize(obj)
            
            if obj.is_a? Hash
              FIELD_MAP.each do |field,func|
                instance_variable_set("@" + field.to_s, obj[func]) rescue nil
              end              
            else
              FIELD_MAP.each do |field,func|
                instance_variable_set("@" + field.to_s, obj.send(func)) rescue nil
              end
            end
          end                    
        end
        
      EVAL

      module_eval(<<-EVAL, __FILE__, __LINE__)
        def #{dto_method_name}
          #{dto_class_name}.new(self)
        end      
      EVAL
      
    end
        
  end
  
  module Dto
    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]

      xml.tag!(self.class.xml_name) do
        self.instance_variables.each do |varname|
          var = self.instance_variable_get(varname)
          if var.is_a?(ActsAsDto::Dto) or var.is_a?(Array)
            xml << var.to_xml(:skip_instruct => true, :root => varname[1..-1], :dasherize => false, :skip_types => true)
          else
            xml.tag!(varname[1..-1],var)
          end
        end
      end
    end    
  end
end