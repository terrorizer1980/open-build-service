# Specifies own namespaces of attributes
# always only 1-level deep, unlike project namespaces

class AttribNamespace < ActiveRecord::Base
  has_many :attrib_types, :dependent => :destroy
  has_many :attrib_namespace_modifiable_by, :class_name => 'AttribNamespaceModifiableBy', :dependent => :destroy

  belongs_to :db_project


  def update_from_xml(node)

    # working without cache, first remove aller permissions
    self.attrib_namespace_modifiable_by.delete_all
    # store permission settings
    if node.has_element? :modifiable_by
      node.each_modifiable_by do |m|
        if not m.has_attribute? :user and not m.has_attribute? :group and not m.has_attribute? :role
          raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
        end
        p={}
        if m.has_attribute? :user
          p[:user] = User.find_by_login(m.user)
          raise RuntimeError, "Unknown user '#{m.user}' in modifiable_by element" if not p[:user]
        end
        if m.has_attribute? :group
          p[:group] = Group.find_by_title(m.group)
          raise RuntimeError, "Unknown group '#{m.group}' in modifiable_by element" if not p[:group]
        end
        if m.has_attribute? :role
          p[:role] = Role.find_by_title(m.role)
          raise RuntimeError, "Unknown role '#{m.role}' in modifiable_by element" if not p[:role]
        end
        self.attrib_namespace_modifiable_by << AttribNamespaceModifiableBy.new(p)
      end
    end
  
    self.save
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))

    if attrib_namespace_modifiable_by.length > 0
      node.namespace(:name => self.name) do |an|
         attrib_namespace_modifiable_by.each do |mod_rule|
           p={}
           p[:user] = mod_rule.user.login if mod_rule.user
           p[:group] = mod_rule.group.title if mod_rule.group
           p[:role] = mod_rule.role.title if mod_rule.role
           an.modifiable_by(p)
         end
      end
    else
      node.namespace(:name => self.name)
    end

  end

  def self.anscache
    return @cache if @cache
    @cache = Hash.new
    find(:all).each do |ns|
      @cache[ns.name] = ns
    end
    return @cache
  end

  def anscache
    self.class.anscache
  end

  def after_create
    logger.debug "updating attrib namespace cache (new ns '#{name}', id \##{id})"
    anscache[name] = self
  end

  def after_update
    logger.debug "updating attrib namespace cache (ns name for id \##{id} changed to '#{name}')"
    anscache.each do |k,v|
      if v.id == id
        anscache.delete k
        break
      end
    end
    anscache[name] = self
  end

  def after_destroy
    logger.debug "updating attrib namespace cache (role '#{name}' deleted)"
    anscache.delete name
  end

end
