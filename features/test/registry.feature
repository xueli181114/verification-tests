Feature: registry related test scenario

  @admin
  @destructive
  Scenario: test security registry
    Given I have a project
    Given I have a registry with htpasswd authentication enabled in my project
    And I select a random node's host
    Given the node service is verified
    And the node service is restarted on the host after scenario
    And I register clean-up steps:
    """
    And I run commands on the host:
      | systemctl restart docker |
    Then the step should succeed
    """
    And the "/etc/sysconfig/docker" file is restored on host after scenario
    And I run commands on the host:
      | sed -i '/^INSECURE_REGISTRY*/d' /etc/sysconfig/docker |
    Then the step should succeed
    And I run commands on the host:
      | echo "INSECURE_REGISTRY='--insecure-registry <%= cb.reg_svc_url%>'" >> /etc/sysconfig/docker |
    Then the step should succeed
    And I run commands on the host:
      | systemctl restart docker |
    Then the step should succeed
    Then I wait up to 60 seconds for the steps to pass:
    """
    And I run commands on the host:
      | docker login -u <%= cb.reg_user %> -p <%= cb.reg_pass %> <%= cb.reg_svc_url %> |
    Then the step should succeed
    """
    And I run commands on the host:
      | docker login -u test -p test <%= cb.reg_svc_url %> |
    Then the step failed

  @admin
  @destructive
  Scenario: simplified steps for registry with htpasswd auth
    Given I have a project
    Given I select a random node's host
    And I have a registry with htpasswd authentication enabled in my project
    And I add the insecure registry to docker config on the node
    And I log into auth registry on the node
    When I docker push on the node to the registry the following images:
      | docker.io/busybox:latest | busybox:latest |
      | centos/ruby-22-centos7   | test/centos7   |
    Then the step should succeed

  @admin
  @destructive
  Scenario: test registry with no auth
    Given I have a project
    Given I select a random node's host
    And I have a registry in my project
    And I add the insecure registry to docker config on the node
    And I log into auth registry on the node
    When I docker push on the node to the registry the following images:
      | docker.io/busybox:latest | busybox:latest |
    Then the step should succeed
  
  @admin
  @destructive
  Scenario: Fail to push to auth registry without login
    Given I have a project
    Given I select a random node's host
    And I have a registry with htpasswd authentication enabled in my project
    And I add the insecure registry to docker config on the node
    When I docker push on the node to the registry the following images:
      | docker.io/busybox:latest | busybox:latest |
      | centos/ruby-22-centos7   | test/centos7   |
    Then the step should fail

  Scenario: Obtain registry ip by creating a build in the project
    Given I have a project
    Given I obtain default registry IP HOSTNAME by a dummy build in the project
    Then the expression should be true> cb.int_reg_ip.to_s =~ /\d+\.\d+\.\d+\.\d+/
