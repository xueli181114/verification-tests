@clusterlogging
Feature: elasticsearch-operator related tests

  # @author qitang@redhat.com
  # @case_id OCP-21332
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for Elasticsearch is deployed along with the Elasticsearch cluster
    Given I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").port == "elasticsearch"
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").path == "/_prometheus/metrics"
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?          |
      | query | es_cluster_nodes_number |
    Then the step should succeed
    And the expression should be true>  @result[:parsed]['data']['result'][0]['value']
    """

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: elasticsearch alerting rules test: ElasticsearchClusterNotHealthy
    Given I obtain test data file "logging/clusterlogging/example.yaml"
    Given I create clusterlogging instance with:
      | remove_logging_pods | true         |
      | crd_yaml            | example.yaml |
    Then the step should succeed
    Given I wait for the "elasticsearch-prometheus-rules" prometheus_rule to appear
    And I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
    When I run the :patch client command with:
      | resource      | clusterlogging                             |
      | resource_name | instance                                   |
      | p             | {"spec": {"managementState": "Unmanaged"}} |
      | type          | merge                                      |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | elasticsearch                              |
      | resource_name | elasticsearch                              |
      | p             | {"spec": {"managementState": "Unmanaged"}} |
      | type          | merge                                      |
    Then the step should succeed
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cluster/settings' -d '{"<cluster_setting>" : {"cluster.routing.allocation.enable" : "none"}} |
      | op           | PUT                                                                                           |
    Then the step should succeed
    And the output should contain:
      | "acknowledged":true |
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | test-index-001 |
      | op           | PUT            |
    Then the step should succeed
    And the output should contain:
      | "acknowledged":true |

    And I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                                     |
      | query | ALERTS{alertname="ElasticsearchClusterNotHealthy"} |
    Then the step should succeed
    And the output should match:
      | "alertstate":"pending\|firing" |
    """
    Examples:
      | cluster_setting |
      | transient       | # @case_id OCP-21530
      | persistent      | # @case_id OCP-30092
