Write and run the webship-js scenarios of one Flutter web app of the workspace.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write webship-js scenarios for the Flutter web app <app> (its <screen> screen) and run them
# ~/workspace/<dev|test|sandboxes|demos> · https://<app>.ddev.site · container-based (DDEV by default)
# the steps read the accessibility tree the app builds for screen readers: a control without a name is a finding about the app
# nothing on the host: no flutter, node, npm or npx outside the app's container
# before writing: the book Automated Functional Testing Recipes (its README.md, then ch15-accessibility-testing.md and ch07-waiting-dynamic-content.md), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-tools-testing.sh <app>
2. Open https://<app>.ddev.site in the Playwright MCP browser, in a tab of your own, click the "Enable accessibility"
   button the app puts first in the page, and take a snapshot of the <screen> screen: note the name the tree gives each
   control, field, heading and dialog, and every control that has none.
3. Write tests/features/<screen>.feature from the installed phrases only
   (grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/flutter-steps/tests/step-definitions/*.steps.js):
   no fixed wait, no framework or platform name in a step, no account created.
4. bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<screen>.feature
5. bash cmd-tools-testing.sh <app> --run --path tests/features/<screen>.feature

If a command fails, show the line that failed and stop. A failing scenario is a result: say what the app did.
When the feature is green: how many scenarios and steps passed, and which controls of the screen have no name.
"""
```
