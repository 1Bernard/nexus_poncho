Feature: Request Access
  As a prospective institutional client
  I want to submit an access request to the Equinox platform
  So that the Equinox team can evaluate my organization for onboarding

  Scenario: Successfully submitting a complete access request
    Given a prospective client submits an access request with:
      | field           | value                |
      | name            | Jane Thornton        |
      | email           | jane@institution.com |
      | organization    | Acme Holdings Ltd    |
      | job_title       | Group Treasurer      |
      | treasury_volume | 100m_500m            |
      | subsidiaries    | 6_20                 |
    Then the access request is accepted
    And the access request is persisted with status "pending"
    And an access request exists for email "jane@institution.com"

  Scenario: Successfully submitting with an optional message
    Given a prospective client submits an access request with:
      | field           | value                             |
      | name            | Robert Chen                       |
      | email           | robert@chenholdings.com           |
      | organization    | Chen Holdings Group               |
      | job_title       | Chief Financial Officer           |
      | treasury_volume | gt_1b                             |
      | subsidiaries    | 100_plus                          |
      | message         | We need multi-entity netting ASAP |
    Then the access request is accepted
    And the access request is persisted with status "pending"

  Scenario: Submitting without required fields is rejected
    Given a prospective client submits an access request with:
      | field | value                      |
      | email | incomplete@institution.com |
    Then the access request is rejected
    And the access request has errors on the "name" field
    And the access request has errors on the "organization" field
    And the access request has errors on the "job_title" field
    And the access request has errors on the "treasury_volume" field
    And the access request has errors on the "subsidiaries" field
    And no access request exists for email "incomplete@institution.com"

  Scenario: Submitting with an invalid email format is rejected
    Given a prospective client submits an access request with:
      | field           | value             |
      | name            | Jane Thornton     |
      | email           | not-a-valid-email |
      | organization    | Acme Holdings     |
      | job_title       | Group Treasurer   |
      | treasury_volume | 100m_500m         |
      | subsidiaries    | 6_20              |
    Then the access request is rejected
    And the access request has errors on the "email" field
    And no access request exists for email "not-a-valid-email"

  Scenario: Submitting with a name that is too short is rejected
    Given a prospective client submits an access request with:
      | field           | value                |
      | name            | J                    |
      | email           | jane@institution.com |
      | organization    | Acme Holdings        |
      | job_title       | Group Treasurer      |
      | treasury_volume | 100m_500m            |
      | subsidiaries    | 6_20                 |
    Then the access request is rejected
    And the access request has errors on the "name" field

  Scenario: Submitting with an invalid treasury volume is rejected
    Given a prospective client submits an access request with:
      | field           | value                |
      | name            | Jane Thornton        |
      | email           | jane@institution.com |
      | organization    | Acme Holdings        |
      | job_title       | Group Treasurer      |
      | treasury_volume | fifty_million        |
      | subsidiaries    | 6_20                 |
    Then the access request is rejected
    And the access request has errors on the "treasury_volume" field
