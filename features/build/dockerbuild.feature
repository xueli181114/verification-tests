Feature: dockerbuild.feature
  # @author wzheng@redhat.com
  # @case_id OCP-12115
  @smoke
  Scenario: Docker build with both SourceURI and context dir
    Given I have a project
    Given I obtain test data file "build/ruby20rhel7-context-docker.json"
    When I run the :create client command with:
      | f | ruby20rhel7-context-docker.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby20-sample-build-1" build was created
    And the "ruby20-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | buildconfig         |
      | name     | ruby20-sample-build |
    Then the step should succeed
    And the output should contain "ContextDir:"

  # @author wzheng@redhat.com
  # @case_id OCP-30854
  Scenario: Docker build with dockerImage with specified tag
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/ruby:2.5                            |
      | app_repo     | https://github.com/openshift/ruby-hello-world |
      | strategy     | docker                                        |
    Then the step should succeed
    And the "ruby-hello-world-1" build completes
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                      |
      | resource_name | ruby-hello-world                                                                                                                                 |
      | p             | {"spec": {"strategy": {"dockerStrategy": {"from": {"kind": "DockerImage","name": "docker.io/centos/ruby-25-centos7:latest"}}},"type": "Docker"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build completes
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                     |
      | resource_name | ruby-hello-world                                                                                                                                |
      | p             | {"spec": {"strategy": {"dockerStrategy": {"from": {"kind": "DockerImage","name": "docker.io/centos/ruby-25-centos7:error"}}},"type": "Docker"}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig      |
      | name     | ruby-hello-world |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-3" build failed
    When I run the :describe client command with:
      | resource | build              |
      | name     | ruby-hello-world-3 |
    Then the step should succeed
    And the output should contain "error"


  # @author dyan@redhat.com
  # @case_id OCP-13083
  Scenario: Docker build using Dockerfile with 'FROM scratch'
    Given I have a project
    When I run the :new_build client command with:
      | D  | FROM scratch\nENV NUM 1 |
      | to | test                    |
    Then the step should succeed
    When the "test-1" build completed
    And I run the :logs client command with:
      | resource_name | bc/test |
      | f             |         |
    Then the output should contain:
      | FROM scratch |
    And the output should not match:
      | [Ee]rror |

  # @author dyan@redhat.com
  # @case_id OCP-12855
  Scenario: Add ARGs in docker build
    Given I have a project
    When I run the :new_build client command with:
      | code      | https://github.com/openshift/ruby-hello-world |
      | build_arg | ARG=VALUE                                     |
    Then the step should succeed
    Given the "ruby-hello-world-1" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-1 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG    |
      | value:\\s+VALUE |
    # start build with build-arg
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | build_arg   | ARG1=VALUE1      |
    Then the step should succeed
    Given the "ruby-hello-world-2" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-2 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG1    |
      | value:\\s+VALUE1 |
    When I run the :start_build client command with:
      | from_build | ruby-hello-world-1 |
      | build_arg  | ARG=NEWVALUE       |
    Then the step should succeed
    Given the "ruby-hello-world-3" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-3 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG       |
      | value:\\s+NEWVALUE |

  # @author wzheng@redhat.com
  # @case_id OCP-18501
  Scenario: Support additional EXPOSE values in new-app
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift-qe/oc_newapp_expose |
    Then the step should succeed
    And the output should contain:
      | invalid ports in EXPOSE instruction |
      | Ports 8080/tcp, 8081/tcp, 8083/tcp, 8084/tcp, 8085/tcp, 8087/tcp, 8090/tcp, 8091/tcp, 8092/tcp, 8093/tcp, 8094/tcp, 8100/udp, 8101/udp |

