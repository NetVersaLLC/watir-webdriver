# encoding: utf-8
require "rubygems"
require "webidl"
require "ruby-debug"
require "pp"

Debugger.start
Debugger.settings[:autoeval] = true
Debugger.settings[:autolist] = 1


class WatirVisitor < WebIDL::RubySexpVisitor

  SPECIALS = {
    'img' => 'image'
  }

  def self.generate_from(file)
    result = []
    result << "# Autogenerated from the HTML5 specification. Edits may be lost."
    result << "module Watir"

    gen  = WebIDL::Generator.new(new)
    code = gen.generate(File.read(file))
    code = "  " + code.split("\n").join("\n  ")

    result << code
    result << "end"

    result.join("\n")
  end

  def visit_interface(interface)
    name   = interface.name
    parent = interface.inherits.first

    return unless name =~ /^HTML/

    if name == "HTMLElement"
      parent = 'BaseElement'
    elsif !(parent && parent.name =~ /^HTMLElement/)
      return
    else
      parent = parent.name
    end

    element_class interface.name,
                  tag_name_from(interface),
                  interface.members.select { |e| e.kind_of?(WebIDL::Ast::Attribute) },
                  parent
  end

  def visit_module(mod)
    # ignored
  end

  def visit_implements_statement(stmt)
    # ignored
  end

  private

  def tag_name_from(interface)
    _, tag_name = interface.extended_attributes.find { |k,v| k == "TagName" }
    tag_name || paramify(interface.name)
  end

  def element_class(name, tag_name, attributes, parent)
    [:class, classify(name), [:const, classify(parent)],
      [:scope, [:block] + [identifier_call(tag_name)]],
      [:scope, [:block] + [container_call(tag_name)]],
      [:scope, [:block] + [collection_call(tag_name)]],
      [:scope, [:block] + [attributes_call(attributes)]]
    ]
  end

  def classify(name)
    if name =~ /^HTML(.+)Element$/
      $1
    else
      name
    end
  end

  def paramify(str)
    if SPECIALS.has_key?(str)
      SPECIALS[str]
    else
      classify(str).snake_case
    end
  end

  def attributes_call(attributes)
    return if attributes.empty?

    attrs = Hash.new { |hash, key| hash[key] = [] }
    attributes.each do |a|
      attrs[ruby_type_for(a.type)] << a.name.snake_case
    end

    call :attributes, [[:hash] + attrs.map { |type, names| [[:lit, type], literal_array(names)] }.flatten(1)]
  end

  def identifier_call(tag_name)
    call :identifier, [literal_hash(:tag_name => tag_name)]
  end

  def container_call(name)
    call :container_method,  [[:lit, paramify(name).to_sym]]
  end

  def collection_call(name)
    call :collection_method, [[:lit, pluralize(paramify(name)).to_sym]]
  end

  def literal_hash(hash)
    [:hash] + hash.map { |k, v| [[:lit, k.to_sym], [:lit, v]] }.flatten(1)
  end

  def literal_array(arr)
    [:array] + arr.map { |e| [:lit, e.to_sym] }
  end

  def call(name, args)
    [:call, nil, name.to_sym, [:arglist] + args]
  end

  def pluralize(name)
    name[/s$/] ? name : name + 's'
  end

  def ruby_type_for(type)
    case type.name.to_s
    when 'DOMString', 'any'
      :string
    when 'unsigned long', 'long', 'integer', 'short', 'unsigned short'
      :int
    when 'float'
      :float
    when 'Function'
      :function
    when 'boolean'
      :bool
    when 'Document'
      :document
    when 'DOMTokenList', 'DOMSettableTokenList'
      :token_list
    when 'DOMStringMap'
      :string_map
    when 'HTMLPropertiesCollection'
      :properties_collection
    when /HTML(.*)Element/
      :html_element
    when /HTML(.*)Collection/
      :html_collection
    when 'CSSStyleDeclaration'
      :style
    when /.+List$/
      :list
    when 'Date'
      :date
    when 'WindowProxy', 'ValidityState', 'MediaError', 'TimeRanges'
      :string
    else
      raise "unknown type: #{type.name}"
    end
  end

end
