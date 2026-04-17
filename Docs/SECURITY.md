# Security Requirements

> *Maintained by: Security Agent*

## Data Classification

### Sensitivity Levels

| Level | Definition | Examples | Storage | Transmission |
|-------|------------|----------|---------|--------------|
| **Public** | No impact if disclosed | App version, feature flags | Any | Any |
| **Internal** | Minor impact | Usage analytics | Encrypted | HTTPS |
| **Confidential** | Significant impact | User preferences, meal history | Encrypted + Protected | HTTPS + Pinning |
| **Restricted** | Severe impact | Auth tokens, health data | Keychain only | HTTPS + Pinning |

### Data Inventory

| Data Type | Classification | Storage Location | Retention |
|-----------|---------------|------------------|-----------|
| [Data type 1] | [Level] | [Location] | [Duration] |
| [Data type 2] | [Level] | [Location] | [Duration] |

---

## Authentication & Authorization

### Authentication Requirements

- [ ] Biometric authentication for sensitive features
- [ ] Session timeout after **[X]** minutes of inactivity
- [ ] Secure token storage in Keychain
- [ ] Token refresh mechanism
- [ ] Logout clears all sensitive data from device

### Authorization Model

| Role | Permissions |
|------|-------------|
| Guest | [Permissions] |
| User | [Permissions] |
| Premium | [Permissions] |

---

## Secure Coding Standards

### Data Storage

```swift
// ✅ Keychain for credentials
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "authToken",
    kSecValueData as String: token.data(using: .utf8)!,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]

// ❌ Never UserDefaults for sensitive data
UserDefaults.standard.set(token, forKey: "authToken") // WRONG
```

### Network Security

- [ ] App Transport Security (ATS) enabled
- [ ] Certificate pinning for auth endpoints
- [ ] No sensitive data in URLs
- [ ] Request/response logging excludes sensitive fields

### Input Validation

- [ ] All user input validated and sanitized
- [ ] Server-side validation (never trust client)
- [ ] Parameterized queries for any database operations

### Cryptography

- [ ] Use iOS Cryptokit for encryption
- [ ] No custom crypto implementations
- [ ] Keys stored in Secure Enclave when possible

---

## Privacy Requirements

### Data Minimization

- [ ] Only collect data necessary for functionality
- [ ] Clear justification for each data point collected
- [ ] Regular audit of data collection

### User Consent

- [ ] Clear privacy policy
- [ ] Consent before collecting optional data
- [ ] Easy opt-out mechanisms

### Data Subject Rights

- [ ] Export user data on request
- [ ] Delete user data on request
- [ ] View what data is collected

### Apple Privacy Requirements

- [ ] Privacy Nutrition Labels accurate
- [ ] App Tracking Transparency (if applicable)
- [ ] No fingerprinting

---

## Threat Model Summary

### Key Threats

| Threat | Likelihood | Impact | Mitigation Status |
|--------|------------|--------|-------------------|
| Credential theft | Medium | High | ⚪ Not started |
| Data leakage | Medium | Medium | ⚪ Not started |
| Man-in-the-middle | Low | High | ⚪ Not started |
| Local data access | Low | Medium | ⚪ Not started |

### Attack Surface

- Network endpoints: [List]
- Local storage: [List]
- User input points: [List]
- Third-party SDKs: [List]

---

## Security Checklist

### Pre-Release

- [ ] Security review completed
- [ ] Penetration testing (if applicable)
- [ ] All HIGH/CRITICAL findings resolved
- [ ] Privacy review completed
- [ ] App Store privacy questionnaire accurate

### Ongoing

- [ ] Dependency vulnerabilities monitored
- [ ] Security incident response plan in place
- [ ] Regular security training for team

---

## Incident Response

### If a security incident occurs:

1. **Contain** - Limit the damage
2. **Assess** - Understand scope and impact
3. **Notify** - Inform affected parties
4. **Remediate** - Fix the vulnerability
5. **Review** - Learn and improve

### Contact

Security issues: [security@example.com]
