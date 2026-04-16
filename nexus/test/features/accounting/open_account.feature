Feature: Accounting: Open Account
  As a system administrator or financial officer
  I want to open a new ledger account
  So that I can track financial positions and movements

  @accounting
  Scenario: Successfully opening a new account
    Given an organization with ID "org_123" exists
    When I open a new account for "Company Cash" with ID "acc_cash_001"
    Then the account "acc_cash_001" should be opened
    And the account "acc_cash_001" should have a balance of 0
    And the event "AccountOpened" should be emitted with:
      | field        | value        |
      | org_id       | org_123      |
      | account_id   | acc_cash_001 |
      | name         | Company Cash |

  @accounting
  Scenario: Opening an account with missing required fields
    Given an organization with ID "org_123" exists
    When I try to open an account without an ID
    Then I should receive an error "account_id_required"
