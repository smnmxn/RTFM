# Security Overview

**Last updated:** January 30, 2025

---

This document describes how supportpages.io protects your data. We're transparent about our security practices because trust requires transparency.

---

## Infrastructure

### Hosting Location
- **Provider:** Hetzner
- **Location:** Finland (EU)
- **Jurisdiction:** EU data protection laws apply

### Why Finland?
We chose EU-based hosting because:
- GDPR compliance is simpler when data stays in the EU
- Hetzner has strong security practices
- Finland has robust data protection laws

### Physical Security
Hetzner data centers feature:
- 24/7 on-site security
- Biometric access controls
- Video surveillance
- Redundant power and cooling

---

## Authentication

### How You Log In
- **GitHub OAuth only** – We don't store passwords
- **Secure tokens** – GitHub provides authentication tokens
- **Session management** – Secure, HTTP-only cookies

### What We Store
- GitHub user ID (not your password)
- GitHub OAuth token (for API access)
- Session tokens (for staying logged in)

### Token Security
- GitHub tokens are stored encrypted
- Sessions expire after inactivity
- You can revoke access from GitHub at any time

---

## Data in Transit

### Encryption
- **TLS 1.2+** for all connections
- **HTTPS only** – HTTP redirects to HTTPS
- **HSTS** – Browsers remember to use HTTPS

### What This Means
When you use supportpages.io:
- Your browser's connection is encrypted
- Data can't be intercepted in transit
- Even we can't see data in transit (end-to-end encryption)

### API Security
- All GitHub API calls use HTTPS
- All Anthropic API calls use HTTPS
- Webhook payloads are signed and verified

---

## Data at Rest

### Database
- Encrypted storage
- Regular backups (also encrypted)
- Backups stored in same region (Finland)

### What We Store
- User accounts and settings
- Project configurations
- Generated documentation
- Usage analytics

### What We Don't Store
- Your raw code (processed temporarily, then deleted)
- Your GitHub password
- Unnecessary personal data

---

## Code Handling

This is the most sensitive part of what we do. Here's exactly how we handle your code:

### Initial Codebase Analysis
1. **Trigger** – You connect a repository and initiate analysis
2. **Clone** – We perform a shallow `git clone` (latest commit only) into a Docker container
3. **AI analysis** – Claude reads your code to understand structure, patterns, and purpose
4. **Output** – AI generates a summary and documentation suggestions
5. **Cleanup** – Docker container is destroyed, your code is deleted
6. **Storage** – Only the generated summary and metadata are stored

### PR Analysis
1. **Webhook received** – GitHub notifies us of a merged PR
2. **Clone** – We shallow-clone your repository into a fresh Docker container
3. **Diff fetched** – We also fetch the specific PR diff from GitHub
4. **AI analysis** – Claude analyzes changes in context of the full codebase
5. **Cleanup** – Docker container is destroyed, your code is deleted
6. **Storage** – Only generated changelog/documentation is stored

### Key Points
- **We do clone your full repository** (shallow—no git history)
- **Code exists only in ephemeral Docker containers**
- **Containers are destroyed after each analysis** (`docker run --rm`)
- **Your source code is never stored in our database**
- **Only AI-generated content persists**
- **Code is sent to one third party: Anthropic**

### Anthropic's Handling
Per our Data Processing Agreement with Anthropic:
- They process your code via API to generate responses
- They don't store your code after the API request completes
- They don't train models on your data
- They don't share your code with third parties

---

## Access Controls

### Internal Access
- **Principle of least privilege** – Staff only access what they need
- **No routine code access** – We don't look at your code
- **Audit logging** – Access is logged

### When We Might Access Data
- **Debugging** – If you report a bug and ask us to investigate
- **Security incidents** – If we need to investigate a breach
- **Legal requirements** – If compelled by law

We'll notify you if we access your data (unless legally prohibited).

### Customer Access
- You access only your own data
- Projects are isolated between users
- Authentication required for all access

---

## Monitoring

### What We Monitor
- Application errors and exceptions
- Performance metrics
- Security events (failed logins, etc.)

### What We Don't Monitor
- Your code content
- Your documentation content
- Your private usage patterns

### Error Logging
We use Rollbar for error monitoring. We filter out:
- OAuth tokens
- Code content
- Sensitive personal data

Errors include stack traces and request info, but not your code.

---

## Incident Response

### If Something Goes Wrong
1. **Detection** – Monitoring alerts us to issues
2. **Assessment** – We evaluate scope and impact
3. **Containment** – We stop the bleeding
4. **Notification** – We tell you what happened (within 72 hours for breaches)
5. **Resolution** – We fix the root cause
6. **Post-mortem** – We learn and improve

### Breach Notification
For personal data breaches, we commit to:
- Notifying affected customers within 72 hours
- Providing details about what happened
- Explaining what we're doing about it

---

## Third-Party Security

### Sub-processor Selection
Before using a sub-processor, we verify:
- They have appropriate security certifications
- They sign data processing agreements
- They meet our security standards

### Current Sub-processors
See our [Sub-processors](/legal/subprocessors) page for details on each provider's security.

### Ongoing Review
We periodically review sub-processor security practices and certifications.

---

## What We Don't Do

To be clear, we don't:
- Sell your data
- Share code with unauthorized parties
- Train AI on your data
- Store passwords
- Use tracking cookies
- Mine your code for insights beyond documentation

---

## Your Responsibilities

Security is a shared responsibility. You should:
- Keep your GitHub account secure (use 2FA)
- Review generated documentation before publishing
- Report security concerns promptly
- Revoke access if you no longer use the service

---

## Reporting Security Issues

Found a vulnerability? Let us know:

**Email:** security@supportpages.io

We appreciate responsible disclosure. We'll:
- Acknowledge receipt within 24 hours
- Keep you updated on our investigation
- Credit you (if you want) when we fix it
- Not take legal action against good-faith researchers

---

## Certifications and Compliance

### Current Status
- **GDPR compliant** – EU hosting, DPA available
- **SOC 2** – Not yet (on our roadmap)

### Roadmap
As we grow, we plan to pursue:
- SOC 2 Type II certification
- ISO 27001 certification

---

## Questions

Have security questions? Contact us:

**Email:** security@supportpages.io

We're happy to discuss our security practices in more detail, sign NDAs for sensitive discussions, or complete security questionnaires.

---

*Security is never "done." We continuously improve our practices. This document reflects our current state as of the date above.*
