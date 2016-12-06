Puppet::Type.newtype(:ovs_patch_trunk) do
  @doc = "set ovs patch trunk on exist bridges"

  ensurable

  newparam(:name) # workarround for following error:
  # Error 400 on SERVER: Could not render to pson: undefined method `merge' for []:Array
  # http://projects.puppetlabs.com/issues/5220

  newparam(:bridges, :array_matching => :all) do
    desc "Bridges that will be set patch trunks"

    validate do |value|
      if !value.is_a?(Array) or value.size() != 2
        fail("Must be an array of two bridge names")
      end
      if !value[0].is_a?(String) or !value[1].is_a?(String)
        fail("Brige name must be a string")
      end
    end
  end

  newparam(:trunks, :array_matching => :all) do
    desc "Allow vlan id ranges"
    defaultto([])

    validate do |value|
      if !value.is_a?(Array) or value.size() != 2
        fail("Must be an array of two vlan id")
      end
      for val in value
        val = val.to_i
        if val < 0 or val > 4095
          fail("vlan id range must be in 1...4095")
        end
      end
    end
  end
end
