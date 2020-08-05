@marketplace
Feature: Marketplace related scenarios

  # @author jiazha@redhat.com
  # @case_id OCP-22618
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: upgrade Marketplace - prepare
    # Check Marketplace version
    Given the "marketplace" operator version matches the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4+, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # Create a new OperatorSource
    Given I obtain test data file "olm/operatorsource-template.yaml"
    And I use the "openshift-marketplace" project
    When I process and create:
      | f | operatorsource-template.yaml |
      | p | NAME=test-operators          |
      | p | SECRET=                      |
      | p | DISPLAYNAME=Test Operators   |
      | p | REGISTRY=jiazha              |
    Then the step should succeed
    # Create a new CatalogSourceConfig
    Given I obtain test data file "olm/csc-template.yaml"
    When I process and create:
      | f | csc-template.yaml                     |
      | p | PACKAGES=codeready-toolchain-operator |
      | p | DISPLAYNAME=CSC Operators             |
    Then the step should succeed
    # Check if the marketplace works well
    And I wait up to 360 seconds for the steps to pass:
    """
    Given the marketplace works well
    """

  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: upgrade Marketplace
    # Check Marketplace version after upgraded
    Given the "marketplace" operator version matches the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4+, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # Check if the marketplace works well
    And I wait up to 360 seconds for the steps to pass:
    """
    Given the marketplace works well
    """
