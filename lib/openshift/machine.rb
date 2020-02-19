require 'openshift/cluster_resource'

module BushSlicer
  # represents Machine
  class Machine < ProjectResource
    RESOURCE = 'machines'

    def machine_set_name(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('metadata', 'labels', 'machine.openshift.io/cluster-api-machineset')
    end

    # returns the node name the machine linked to
    def node_name(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('status', 'nodeRef', 'name')
    end

    def phase(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('status','phase')
    end

    def ready?(user: nil, cached: true, quiet: false)
      instance_state = raw_resource(user: user, cached: cached, quiet: quiet).
        dig('status','providerStatus','instanceState')
      instance_state == 'running'
    end
  end
end
