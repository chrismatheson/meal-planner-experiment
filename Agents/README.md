# iOS Development Agent Framework

A collaborative AI agent system designed to build top-class iOS applications using Swift and SwiftUI.

## Agent Roster

| Agent | Role | Primary Focus |
|-------|------|---------------|
| **Product Manager** | Vision Keeper | Features, roadmap, user stories, acceptance criteria |
| **Architect** | System Designer | Patterns, data flow, module boundaries, scalability |
| **Developer** | Implementation | Swift, SwiftUI, clean code, Apple frameworks |
| **QA** | Quality Guardian | Testing strategies, automation, edge cases, regression |
| **Security** | Risk Mitigator | Threat modeling, secure coding, data protection |
| **Designer** | UX Champion | UI patterns, accessibility, Human Interface Guidelines |

## Workflow

```
┌─────────────────┐
│ Product Manager │ ← Defines WHAT and WHY
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────┐
│   Architect     │────▶│ Designer │ ← Defines HOW (structure + UX)
└────────┬────────┘     └────┬─────┘
         │                   │
         └─────────┬─────────┘
                   ▼
         ┌─────────────────┐
         │   Developer     │ ← Implements
         └────────┬────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────┐    ┌──────────────┐
│     QA      │    │   Security   │ ← Validates
└─────────────┘    └──────────────┘
```

## Usage

Each agent is defined in its own directory with:
- `AGENT.md` - The agent's persona, responsibilities, and prompts
- Additional context files as needed

### Invoking Agents

When working on a feature:

1. **Start with PM** - Define the feature spec
2. **Consult Architect** - Design the implementation approach  
3. **Involve Designer** - Ensure great UX
4. **Developer implements** - Write the code
5. **QA validates** - Test thoroughly
6. **Security reviews** - Check for vulnerabilities

### Cross-Cutting Concerns

All agents share these principles:
- **User-first thinking** - Every decision serves the user
- **Apple platform excellence** - Follow HIG, use native patterns
- **Maintainability** - Code that future-you will thank you for
- **Performance** - 60fps, fast launch, responsive UI

## Project Context

This framework is for: **MealPlanner** - A meal planning iOS application

Agents should maintain awareness of:
- `Docs/VISION.md` - Product vision and goals
- `Docs/ARCHITECTURE.md` - Technical architecture decisions
- `Docs/ROADMAP.md` - Feature roadmap and priorities
