Feature: The counter
  The app of `flutter create`, built for the web: a heading, a line that counts, and a button. Built with
  `bash cmd-flutter-project.sh flapp --install`, at the address of the app.

  Background:
    Given I am on the homepage
    And the app's accessibility tree is on

  @critical
  Scenario: The button adds one to the count, once per tap
    Then the app should show the "Flutter Demo Home Page" heading
    And the app should show "You have pushed the button this many times: 0"
    When I tap "Increment"
    Then the app should show "You have pushed the button this many times: 1"
    When I tap the "Increment" button
    And I tap "Increment"
    Then the app should show "You have pushed the button this many times: 3"
    And the app should not show "You have pushed the button this many times: 4"

  Scenario: What the app holds, by role and name
    Then the app should show the "Increment" button
    And the app's "Increment" button should be enabled
    And the app should not show the "Decrement" button
    And the app should have no unnamed buttons
    And the app should be on "/"
    And the app should run as JavaScript
