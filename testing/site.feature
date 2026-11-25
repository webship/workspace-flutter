Feature: The app answers and its counter counts
  As the owner of the app
  I want it to start in the browser and its button to count
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup for the counter of `flutter create`, as a starting point: it is yours to
  # change. The steps read the accessibility tree the app builds for screen readers; the first one turns it on, as
  # assistive technology does.

  @critical
  Scenario: The app starts with its heading and a count of nothing
    Given I am on the homepage
    And the app's accessibility tree is on
    Then the app should show the "Flutter Demo Home Page" heading
    And the app should show "You have pushed the button this many times: 0"

  @critical
  Scenario: The button adds one to the count, once per tap
    Given I am on the homepage
    When I tap "Increment"
    Then the app should show "You have pushed the button this many times: 1"
    When I tap the "Increment" button
    Then the app should show "You have pushed the button this many times: 2"

  Scenario: A screen reader can name every button
    Given I am on the homepage
    Then the app should show the "Increment" button
    And the app should have no unnamed buttons
