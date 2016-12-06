Puppet::Type.type(:ovs_patch_trunk).provide(:ovs) do
  desc "set ovs patch trunks"

  commands :ovs_vsctl => "/usr/bin/ovs-vsctl"

  def exists?
    # check if trunks has exists
    br1 = resource[:bridges][0]
    br2 = resource[:bridges][1]

    trunk1 = get_ovs_patch_trunks(br1, br2)
    trunk2 = get_ovs_patch_trunks(br2, br1)

    if !trunk_is_equal(trunk1, resource[:trunks]) or
      !trunk_is_equal(trunk2, resource[:trunks])
      return false
    end
    return true
  end

  def create
    br1 = resource[:bridges][0]
    br2 = resource[:bridges][1]
    ovs_trunks = cover_vlan_range_to_string(resource[:trunks])

    set_ovs_patch_trunks(br1, br2, ovs_trunks)
    set_ovs_patch_trunks(br2, br1, ovs_trunks)
  end

  def destroy
    br1 = resource[:bridges][0]
    br2 = resource[:bridges][1]
    ovs_trunks = cover_vlan_range_to_string(resource[:trunks])

    del_ovs_patch_trunks(br1, br2, ovs_trunks)
    del_ovs_patch_trunks(br2, br1, ovs_trunks)
  end

  private
  def get_ovs_patch_trunks(br, peer_br)
    interface = "#{br}--#{peer_br}"
    trunks = []
    begin
      trunks = ovs_vsctl('get', 'Port', "#{interface}", 'trunks')
      # eval to array
      trunks = eval(trunks.rstrip)
    rescue puppet::executionfailure => errmsg
      raise puppet::executionfailure, "can't get patch '#{interface}' trunks:\n#{errmsg}"
    end
    return trunks
  end

  def set_ovs_patch_trunks(br, peer_br, trunks)
    interface = "#{br}--#{peer_br}"
    # Dont overrwrite exists trunks
    orig_trunk = get_ovs_patch_trunks(br, peer_br)
    if !orig_trunk.empty?
      orig_trunk = orig_trunk.join(',')
      trunks = trunks + ',' + orig_trunk
    end

    begin
      ovs_vsctl('set', 'Port', "#{interface}", "trunks=#{trunks}")
    rescue puppet::executionfailure => errmsg
      raise puppet::executionfailure, "can't set patch '#{interface}' to trunks '#{trunks}':\n#{errmsg}"
    end
  end

  def del_ovs_patch_trunks(br, peer_br, trunks)
    interface = "#{br}--#{peer_br}"
    begin
      ovs_vsctl('remove', 'Port', "#{interface}", 'trunks' ,"#{trunks}")
    rescue puppet::executionfailure => errmsg
      raise puppet::executionfailure, "can't delete patch '#{interface}'  trunks '#{trunks}':\n#{errmsg}"
    end
  end

  def cover_vlan_range_to_string(trunk)
    (trunk[0]..trunk[1]).to_a().join(',')
  end

  def trunk_is_equal(trunk1,trunk2)
    trunk1 = trunk1.map {|x| x.to_i}
    trunk2 = trunk2.map {|x| x.to_i}
    return trunk1.sort == trunk2.sort
  end
end
