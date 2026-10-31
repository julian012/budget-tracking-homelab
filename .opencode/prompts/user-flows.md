Act as a UX Architect and Tech Writer specializing in Flutter.

I need to create visual documentation of the screen flow for my mobile finance app. Follow these steps:

1. ANALYZE THE CURRENT PROJECT:
   - Examine the files inside `lib/` (routes, screens, modals, navigation widgets).
   - Read our visual rules file (`design-tokens.json` / UI rules).

2. GENERATE THE `user-flows.md` FILE AT THE PROJECT ROOT:
   - Include a general visual navigation map using **Mermaid.js** code (`graph TD`).
   - Document the main flows (e.g., Dashboard, Add Expense, Reports, History) based on what you find in the project's current structure.
   - For each screen, specify:
     * Screen name and Flutter route.
     * UX purpose and Material Design 3 components used.
     * Transitions and triggers (which button or gesture leads to which screen).
      * A screenshot placeholder with the path `./docs/screenshots/[descriptive_name].png`.

3. ITERATIVE REFINEMENT:
   - This is a living document that we will iterate on as we add or change screens. Refine it to reflect the project's actual state today, clearly marking any screen or flow that is still pending implementation.
