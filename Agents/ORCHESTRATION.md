# Agent Orchestration

How the agents collaborate to build great iOS applications.

## ⚠️ Critical Gates

**No phase is complete without evidence that it works.**

See also:
- [TESTING_PHILOSOPHY.md](TESTING_PHILOSOPHY.md) - TDD and mocking approach
- [QUALITY_GATES.md](QUALITY_GATES.md) - Phase completion requirements

### Definition of Done

| Phase | Required Evidence | QA Action |
|-------|-------------------|-----------|
| Feature Dev | Failing test → Passing test → Code committed | - |
| Integration | Test hits real API and passes | QA verifies, updates TEST_PLAN.md |
| UI Complete | UI test runs and passes | QA verifies, updates TEST_PLAN.md |
| MVP Complete | Full app run-through with real credentials | QA runs all manual tests, updates TEST_PLAN.md |
| **Handoff to User/PO** | QA sign-off required | QA audits TEST_PLAN.md reflects reality |

## Invocation Pattern

When working on a feature, invoke agents using this prompt structure:

```
Acting as the [AGENT NAME] agent (see Agents/[Name]/AGENT.md), 
[your request here]
```

### Example Invocations

```
Acting as the Product Manager agent, write a feature spec for 
weekly meal planning with nutrition tracking.
```

```
Acting as the Security agent, review this authentication flow 
and identify potential vulnerabilities.
```

```
Acting as the QA agent, design test cases for the meal 
creation feature.
```

## Workflow Templates

### 🔍 Discovery Workflow (Before Building)

```mermaid
sequenceDiagram
    participant PM as Product Manager
    participant Res as Researcher
    participant Arch as Architect
    participant Des as Designer

    PM->>Res: What integration do we need?
    Res->>Res: Investigate API/technology
    Res->>Arch: Here's what's possible
    Arch->>Arch: Design with real constraints
    PM->>Des: Audit target app's design
    Des->>Des: Extract design system
```

**Use this workflow when:**
- Integrating with external APIs (especially undocumented)
- Evaluating new technologies
- Starting a new product area

### 🆕 New Feature Workflow

```mermaid
sequenceDiagram
    participant PM as Product Manager
    participant Res as Researcher
    participant Arch as Architect
    participant Des as Designer
    participant Dev as Developer
    participant QA as QA
    participant Sec as Security

    PM->>PM: Write feature spec
    PM->>Res: Any unknowns to research?
    Res->>Arch: Research findings
    PM->>Arch: Review for feasibility
    Arch->>Arch: Design solution
    Arch->>Des: Collaborate on UX
    Des->>Des: Create designs
    Des->>Dev: Hand off specs
    Dev->>Dev: Implement
    Dev->>QA: Ready for testing
    QA->>QA: Test & file bugs
    Dev->>Sec: Security review
    Sec->>Sec: Threat model
    QA->>PM: Sign off
```

### 🐛 Bug Fix Workflow

```
1. QA → Detailed bug report
2. Developer → Root cause analysis
3. Developer → Fix implementation  
4. QA → Verify fix
5. Security → Review if security-related
```

### 🔒 Security Review Workflow

```
1. Security → Threat model the feature
2. Security → Review code for vulnerabilities
3. Developer → Implement mitigations
4. Security → Verify mitigations
5. QA → Security test cases
```

## Handoff Documents

### PM → Development Team
- Feature spec with acceptance criteria
- User stories prioritized
- Success metrics defined

### Architect → Developer
- Architecture Decision Record (ADR)
- Module design doc
- API contracts

### Designer → Developer
- Screen mockups with specs
- Component library reference
- Animation specifications
- Accessibility requirements

### Developer → QA
- PR/code ready for testing
- Known limitations
- Test environment setup

### QA → Everyone
- Test results
- Bug reports
- Risk assessment

## Multi-Agent Collaboration Prompts

### Design Review
```
I need a cross-functional review of this feature:

1. Acting as the Product Manager: Does this meet user needs?
2. Acting as the Architect: Is this technically sound?
3. Acting as the Designer: Is the UX optimal?
4. Acting as the Security agent: What are the risks?
```

### Code Review
```
Review this code from multiple perspectives:

1. Acting as the Developer: Is this clean, idiomatic Swift?
2. Acting as the QA agent: Is this testable? What should we test?
3. Acting as the Security agent: Any vulnerabilities?
```

### Pre-Launch Checklist
```
Acting as each agent, confirm readiness for launch:

1. PM: Are acceptance criteria met?
2. Architect: Is the code maintainable?
3. Designer: Does UX match specs?
4. Developer: Are there known issues?
5. QA: What's the test coverage?
6. Security: Are there open vulnerabilities?
```

## Context Files

Agents should reference these shared documents:

| File | Purpose | Updated By |
|------|---------|------------|
| `Docs/VISION.md` | Product vision and goals | PM |
| `Docs/ARCHITECTURE.md` | Technical decisions | Architect |
| `Docs/ROADMAP.md` | Feature priorities | PM |
| `Docs/DESIGN_SYSTEM.md` | UI components | Designer |
| `Docs/SECURITY.md` | Security requirements | Security |

## Background Activities

Some work can run in parallel with active development:

| Activity | When to Run | Owner |
|----------|-------------|-------|
| Roadmap refinement | Ongoing, after user feedback | PM |
| Technical debt tracking | After each sprint | Architect |
| Security threat modeling | When new features planned | Security |
| Test coverage analysis | After major features | QA |

### Running Background Tasks

Background activities should not block development but inform future priorities.
Use the PM agent to periodically review and update the roadmap based on:
- User/PO feedback
- Technical discoveries
- Market changes

## Best Practices

1. **Start with PM** - Features without specs drift
2. **Architect early** - Redesign is expensive
3. **Security by design** - Bolt-on security fails
4. **QA throughout** - Not just at the end
5. **Document decisions** - Future you will thank you
6. **Commit often** - At reasonable checkpoints, not just at the end

## Conflict Resolution

When agents disagree:

1. **User value wins** - What's best for the user?
2. **Data decides** - Can we test the hypothesis?
3. **Ship and learn** - Perfect is the enemy of good
4. **PM breaks ties** - Someone has to decide
