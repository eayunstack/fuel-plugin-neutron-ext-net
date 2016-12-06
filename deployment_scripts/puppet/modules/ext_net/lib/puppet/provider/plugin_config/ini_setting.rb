Puppet::Type.type(:plugin_config).provide(
  :ini_setting,
  :parent => Puppet::Type.type(:ini_setting).provider(:ruby)
) do

  def section
    resource[:name].split('/', 2).first
  end

  def setting
    resource[:name].split('/', 2).last
  end

  def separator
    '='
  end

  def value=(value)
    append_value
    super
  end

  def create
    append_value
    super
  end

  def self.file_path
    '/etc/neutron/plugin.ini'
  end

  # added for backwards compatibility with older versions of inifile
  def file_path
    self.class.file_path
  end

  private
  def append_value
    if resource[:append_to_list] and exists?
      clist = value.strip.split(',')
      resource[:value] = clist.push(resource[:value]).uniq.join(',')
    end
  end

end
