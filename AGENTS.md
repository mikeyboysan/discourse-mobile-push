<!-- lattice:verification -->
Before declaring any work done, run this project's verification suite (.lattice/verification.yaml): spawn the `verifier` subagent when the host supports subagents; otherwise run `.lattice/scripts/run-verification.sh .lattice/verification.yaml` and read summary.json from the printed run directory. Green → reply in one line. Red → headline, failed stage name(s), their log paths; never open or paste a log into the session. Never mark work complete while any stage fails.
<!-- /lattice:verification -->

Exception to the verification rule above: document-only changes do not require verification. A change is document-only when every changed file is Markdown (`*.md`), e.g. `docs/`, `README.md`, `CHANGELOG.md`, `.lattice/**/*.md`. Any other changed file (code, specs, locales, settings, `.lattice/verification.yaml`, scripts) requires verification.
