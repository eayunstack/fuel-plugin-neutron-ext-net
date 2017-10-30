## NB: This must work with Ruby 1.8!

# This requires that network names be unique.  If there are multiple matches
# for a given network name, this provider will raise an exception.

require 'rubygems'
require 'net/http'
require 'net/https'
require 'json'

class NeutronError < Puppet::Error
end

class NeutronConnectionError < NeutronError
end

class NeutronAPIError < NeutronError
end

# Provides common request handling semantics to the other methods in
# this module.
#
# +req+::
#   An HTTPRequest object
# +url+::
#   A parsed URL (returned from URI.parse)
def handle_request(req, url)
    begin
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = url.scheme == 'https'
        res = http.request(req)

        if res.code != '200'
            raise NeutronAPIError, "Received error response from Neutron server at #{url}: #{res.message}"
        end
    rescue Errno::ECONNREFUSED => detail
        raise NeutronConnectionError, "Failed to connect to Neutron server at #{url}: #{detail}"
    rescue SocketError => detail
        raise NeutronConnectionError, "Failed to connect to Neutron server at #{url}: #{detail}"
    end

    res
end

# Authenticates to a Keystone server and obtains an authentication token.
# It returns a 2-element +[token, authinfo]+, where +token+ is a token
# suitable for passing to openstack apis in the +X-Auth-Token+ header, and
# +authinfo+ is the complete response from Keystone, including the service
# catalog (if available).
#
# +auth_url+::
#   Keystone endpoint URL.  This function assumes API version
#   2.0 and an administrative endpoint, so this will typically look like
#   +http://somehost:35357/v2.0+.
#
# +username+::
#   Username for authentication.
#
# +password+::
#   Password for authentication
#
# +tenantID+::
#   Tenant UUID
#
# +tenantName+::
#   Tenant name
#
def keystone_v2_authenticate(auth_url,
                             username,
                             password,
                             tenantId=nil,
                             tenantName=nil)

    post_args = {
        'auth' => {
            'passwordCredentials' => {
                'username' => username,
                'password' => password
            },
        }}

    if tenantId
        post_args['auth']['tenantId'] = tenantId
    end

    if tenantName
        post_args['auth']['tenantName'] = tenantName
    end

    url = URI.parse("#{auth_url}/tokens")
    req = Net::HTTP::Post.new url.path
    req['content-type'] = 'application/json'
    req.body = post_args.to_json

    res = handle_request(req, url)
    data = JSON.parse res.body
    return data['access']['token']['id']
end

# Queries a Neutron server to a list of all networks.
#
# +neutron_url+::
#   Neutron endpoint.
#
# +net_name+::
#   Filter by network name.
#
# +token+::
#   A Keystone token that will be passed in requests as the value of the
#   +X-Auth-Token+ header.
#
def neutron_v2_networks(neutron_url,
			net_name,
                        token)

    url = URI.parse("#{neutron_url}/networks?name=#{net_name}")
    req = Net::HTTP::Get.new url.path
    req['content-type'] = 'application/json'
    req['x-auth-token'] = token

    res = handle_request(req, url)
    data = JSON.parse res.body
    data['networks']
end

Puppet::Parser::Functions::newfunction(:get_network_info, :type => :rvalue) do |args|
  @auth_url = args[0]
  @auth_username = args[1]
  @auth_password = args[2]
  @auth_tenant_name = args[3]
  @neutron_url = args[4]
  @net_name = args[5]

  def authenticate
      keystone_v2_authenticate(
        @auth_url,
        @auth_username,
        @auth_password,
        nil,
        @auth_tenant_name)
  end

  def find_network_by_name (token)
      networks  = neutron_v2_networks(
          @neutron_url,
	  @net_name,
          token)

      networks.select{|network| network['name'] == @net_name}
  end

  # This looks for the network specified by the 'net_name' parameter to
  # the resource and returns the corresponding UUID if there is a single
  # match.
  #
  # Raises a NeutronAPIError if:
  #
  # - There are multiple matches, or
  # - There are zero matches
  def get_network_info
      token = authenticate
      networks = find_network_by_name(token)
      notice(networks)

      if networks.length == 1
          return networks[0]
      elsif networks.length > 1
          raise NeutronAPIError, 'Found multiple matches for network name'
      else
          raise NeutronAPIError, 'Unable to find matching network'
      end
  end
  
  return get_network_info
end
