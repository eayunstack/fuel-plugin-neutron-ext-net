module Puppet::Parser::Functions
  newfunction(:get_ext_phy_bridge, :type => :rvalue) do |args|
    # parse network_scheme
    net_scheme = args[0]
    ex_br_name = net_scheme['roles']['ex']
    ext_phy_br_name = ''

    # find transformations for ex_br
    net_scheme['transformations'].each do |item|
      if item['action'] == 'add-patch'
        if item['bridges'][0] == ex_br_name
          ext_phy_br_name = item['bridges'][1]
          break
        end

        if item['bridges'][1] == ex_br_name
          ext_phy_br_name = item['bridges'][0]
          break
        end
      end
    end
    ext_phy_br_name
  end
end
