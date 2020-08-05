Feature: Testing haproxy router
  # @author bmeng@redhat.com
  # @case_id OCP-11903
  @smoke
  Scenario: haproxy cookies based sticky session for unsecure routes
    #create route and service which has two endpoints
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/unsecure/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    Given I have a pod-for-ping in the project
    #access the route without cookies
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -c |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]
    """
    #access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -b |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access == @result[:response]
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11130
  Scenario: haproxy cookies based sticky session for edge termination routes
    #create route and service which has two endpoints
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/edge/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | service | service-unsecure |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    #access the route without cookies
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]
    """
    #access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -b |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access == @result[:response]
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11619
  Scenario: Limit the number of TCP connection per IP in specified time period
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    Given I obtain test data file "routing/passthrough/service_secure.json"
    When I run the :create client command with:
      | f | service_secure.json |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name | route-pass |
      | service | service-secure |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain 20 times:
      | Hello-OpenShift |
    And the output should not contain "(35)"

    When I run the :annotate client command with:
      | resource | route |
      | resourcename | route-pass |
      | keyval | haproxy.router.openshift.io/rate-limit-connections=true |
      | keyval | haproxy.router.openshift.io/rate-limit-connections.rate-tcp=5 |
    Then the step should succeed

    Given 10 seconds have passed
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain:
      | Hello-OpenShift |
      | (35) |

    Given 6 seconds have passed
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain:
      | Hello-OpenShift |
      | (35) |

  # @author hongli@redhat.com
  # @case_id OCP-15044
  @admin
  Scenario: The backend health check interval of unsecure route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/list_for_caddy.json"
    When I run the :create client command with:
      | f | list_for_caddy.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard

    # create unsecure route
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                   |
      | resourcename | service-unsecure                                        |
      | overwrite    | true                                                    |
      | keyval       | router.openshift.io/haproxy.health.check.interval=200ms |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 200ms |
    """

  # @author hongli@redhat.com
  # @case_id OCP-15049
  @admin
  Scenario: The backend health check interval of edge route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/list_for_caddy.json"
    When I run the :create client command with:
      | f | list_for_caddy.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard

    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                   |
      | resourcename | edge-route                                              |
      | overwrite    | true                                                    |
      | keyval       | router.openshift.io/haproxy.health.check.interval=300ms |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 300ms |
    """

  # @author bmeng@redhat.com
  # @case_id OCP-10043
  Scenario: Set balance leastconn for passthrough routes
    Given I have a project
    And I store an available router IP in the :router_ip clipboard
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/passthrough/service_secure.json"
    When I run the :create client command with:
      | f | service_secure.json |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name | route-pass |
      | service | service-secure |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource | route |
      | resourcename | route-pass |
      | keyval | haproxy.router.openshift.io/balance=leastconn |
      | overwrite | true |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And I use the "service-secure" service
    When I execute on the pod:
      | curl                                                   |
      | -ksS                                                   |
      | --resolve                                              |
      | <%= route("route-pass").dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-pass").dns(by: user) %> |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    When I execute on the pod:
      | curl                                                   |
      | -ksS                                                   |
      | --resolve                                              |
      | <%= route("route-pass").dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-pass").dns(by: user) %> |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]

  # @author yadu@redhat.com
  # @case_id OCP-11679
  Scenario: Disable haproxy hash based sticky session for unsecure routes
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/unsecure/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                            |
      | resourcename | service-unsecure                                 |
      | overwrite    | true                                             |
      | keyval       | haproxy.router.openshift.io/disable_cookies=true |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -c |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    When I execute on the pod:
      | bash | -c | for i in {1..10} ; do curl -sS  http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ -b /tmp/cookies ; done |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift-1 |
      | Hello-OpenShift-2 |

  # @author hongli@redhat.com
  # @case_id OCP-15872
  Scenario: can set cookie name for unsecure routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/unsecure/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                             |
      | resourcename | service-unsecure                                  |
      | overwrite    | true                                              |
      | keyval       | router.openshift.io/cookie_name=unsecure-cookie_1 |
    Then the step should succeed

    Given I wait up to 30 seconds for the steps to pass:
    """
    When I open web server via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "unsecure-cookie_1"}
    """
    And evaluation of `@result[:response]` is stored in the :first_access clipboard

    #access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I wait for a web server to become available via the "service-unsecure" route
    Then the expression should be true> cb.first_access == @result[:response]
    """

  # @author hongli@redhat.com
  # @case_id OCP-15873
  Scenario: can set cookie name for edge routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    Given I obtain test data file "routing/caddy-docker-2.json"
    When I run the :create client command with:
      | f | caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/edge/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                         |
      | resourcename | edge-route                                    |
      | overwrite    | true                                          |
      | keyval       | router.openshift.io/cookie_name=2-edge_cookie |
    Then the step should succeed

    When I use the "service-unsecure" service
    And I wait up to 30 seconds for the steps to pass:
    """
    When I open secure web server via the "edge-route" route
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "2-edge_cookie"}
    """
    And evaluation of `@result[:response]` is stored in the :first_access clipboard

    #access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I wait for a secure web server to become available via the "edge-route" route
    And the expression should be true> cb.first_access == @result[:response]
    """
