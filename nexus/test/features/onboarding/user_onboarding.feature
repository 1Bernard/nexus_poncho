Feature: Sovereign Onboarding
  As an unverified user
  I want to register an account and undergo an automated PEP screening
  So that I can securely fund my sovereign ledger

  Scenario: Clean user successfully registers and clears PEP screening
    Given a new user provides their biometric signature "bio_8899" and email "auditor@nexus.com"
    When the RegisterUser command is dispatched
    Then the OnboardingProcessManager should intercept the UserRegistered event
    And the Compliance engine should initiate a PEP check
    When the external PEP screening returns a "clean" status
    Then the OnboardingProcessManager should finalize the onboarding
