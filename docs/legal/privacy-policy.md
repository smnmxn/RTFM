# Privacy Policy

**Last updated:** January 30, 2025

---

## Who We Are

supportpages.io is a developer tool that automatically generates user-facing documentation from your code changes. When you merge a pull request, we analyze the diff and create help articles, changelogs, and other documentation.

We're a small team building tools for developers. We understand that giving any service access to your code requires trust, which is why this policy is written in plain language—not legalese.

**Contact:** privacy@supportpages.io

---

## What This Policy Covers

This policy explains:
- What data we collect
- How we use it
- Who we share it with
- How long we keep it
- Your rights over your data

This applies to supportpages.io and any subdomains (like your-project.supportpages.io).

---

## Information We Collect

### When You Sign Up (via GitHub OAuth)

When you authenticate with GitHub, we receive and store:
- Your GitHub user ID
- Your GitHub username
- Your name (if set on GitHub)
- Your email address
- An access token to interact with GitHub on your behalf

We request the following GitHub scopes:
- `read:user` – to identify you
- `user:email` – to get your email for notifications

### When You Connect a Repository

When you install our GitHub App on a repository, we receive:
- Repository name and metadata
- Webhook notifications when PRs are merged or commits are pushed
- Access to read code diffs for analysis

### When We Analyze Your Code

This is important, so we'll be clear about our security measures:

**Initial Codebase Analysis (when you first connect a repository):**
1. We create a temporary, isolated copy of your repository (current state only—no version history)
2. This copy exists in a secure, sandboxed environment
3. Our AI analyzes the code structure and generates documentation suggestions
4. **The environment is destroyed immediately after analysis**
5. We store only the generated summary and metadata—not your source code

**Ongoing PR Analysis (when you merge a pull request):**
1. GitHub notifies us of the change
2. We create another temporary, isolated copy for context
3. Our AI analyzes the changes and generates documentation
4. **The isolated environment is destroyed; your code is deleted**

**Security measures:**
- Your code only exists in isolated, ephemeral environments during analysis
- Each analysis runs in a fresh environment that's destroyed after use
- Environments are sandboxed with no persistent storage
- We never store your source code in our database
- Only AI-generated documentation and metadata are retained

### Generated Content

We store:
- Help articles we generate
- Article metadata (titles, sections, publish status)
- Your edits and customizations

### Waitlist Information

If you join our waitlist, we collect:
- Email address
- Name and company (if provided)
- Information about your use case

### Usage Data

We track:
- AI API usage (tokens, costs) for billing purposes
- Error logs for debugging (we filter out sensitive data)

---

## How We Use Your Information

We use your data to:

1. **Provide the service** – Analyze your code and generate documentation
2. **Authenticate you** – Verify your identity via GitHub
3. **Send notifications** – Alert you when new documentation is ready (opt-in)
4. **Improve the product** – Fix bugs and improve AI output quality
5. **Communicate with you** – Respond to support requests, send important updates

We never sell your data. We never use your code to train AI models.

---

## Code Access: The Important Bit

Let's be clear about what happens with your code:

### What We Access
- **Your repository contents** (current state only—no version history)
- Code changes from merged pull requests
- Commit messages and PR descriptions

### What Gets Analyzed
- Your source code files (temporarily, during analysis)
- Code changes and surrounding context
- Project metadata you've provided

### What We Store
- Generated articles and documentation
- Metadata about analyzed changes (PR number, URL)
- AI-generated summaries of your codebase
- **NOT your actual source code**

### What Our AI Provider Receives
- Your source code (temporarily, for analysis)
- Per our agreement: they do not store your code after processing
- Per our agreement: they do not train models on your data

### The Lifecycle of Your Code
1. **Copy** → Your code is copied into an isolated, secure environment
2. **Analyze** → AI reads the code and generates documentation
3. **Delete** → The environment is destroyed, your code is gone
4. **Store** → Only the generated documentation remains

This happens for each analysis. We never accumulate or archive your source code.

---

## Third-Party Services

We share data with these services to operate supportpages.io:

### Anthropic
**Purpose:** AI analysis and documentation generation
**Data shared:** Source code (temporarily), project context
**Location:** USA
**Privacy policy:** [anthropic.com/privacy](https://www.anthropic.com/privacy)

### GitHub
**Purpose:** Authentication, repository access, webhooks
**Data shared:** OAuth tokens, repository data
**Location:** USA
**Privacy policy:** [docs.github.com/privacy](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement)

### Hetzner
**Purpose:** Infrastructure hosting
**Data shared:** All stored data
**Location:** Finland (EU)
**Privacy policy:** [hetzner.com/privacy](https://www.hetzner.com/legal/privacy-policy)

### Cloudflare
**Purpose:** DNS, custom domains, SSL certificates
**Data shared:** Domain names, traffic routing
**Location:** Global (EU data stays in EU)
**Privacy policy:** [cloudflare.com/privacy](https://www.cloudflare.com/privacypolicy/)

### Rollbar (Optional)
**Purpose:** Error monitoring
**Data shared:** Error logs (code filtered out)
**Location:** USA
**Privacy policy:** [rollbar.com/privacy](https://rollbar.com/privacy/)

---

## Where Your Data Lives

Your data is stored on servers in **Finland**, within the European Union. This means:
- EU data protection laws (GDPR) apply
- Your data doesn't leave the EU for storage
- Hetzner provides the infrastructure

When data is sent to US-based services (Anthropic, GitHub), appropriate safeguards are in place. See "International Transfers" below.

---

## How Long We Keep Data

| Data Type | Retention |
|-----------|-----------|
| Account data | Until you delete your account |
| Generated articles | Until you delete them or your account |
| Code diffs | Deleted immediately after processing |
| Error logs | 90 days |
| Waitlist entries | Until you sign up or ask to be removed |
| Usage analytics | 2 years |

When you delete your account, we delete:
- Your user profile
- All your projects and generated content
- Associated usage data

Some data may remain in backups for up to 30 days.

---

## Your Rights

### If You're in the EU (GDPR)

You have the right to:
- **Access** – Get a copy of your data
- **Rectification** – Correct inaccurate data
- **Erasure** – Delete your data ("right to be forgotten")
- **Portability** – Export your data in a standard format
- **Restriction** – Limit how we process your data
- **Object** – Stop certain types of processing
- **Withdraw consent** – For any consent-based processing

### If You're in California (CCPA)

You have the right to:
- **Know** – What personal information we collect
- **Delete** – Request deletion of your data
- **Opt-out** – Of sale of personal information (we don't sell data)
- **Non-discrimination** – We won't treat you differently for exercising rights

### How to Exercise Your Rights

Email us at **privacy@supportpages.io** with your request. We'll respond within 30 days.

To delete your account, you can also go to Settings → Delete Account in the app.

---

## International Transfers

Our servers are in the EU (Finland), but some data is processed by US-based services:

| Service | Location | Safeguard |
|---------|----------|-----------|
| Anthropic | USA | Standard Contractual Clauses, Data Processing Agreement |
| GitHub | USA | Standard Contractual Clauses, EU-US Data Privacy Framework |
| Rollbar | USA | Standard Contractual Clauses |

We ensure all transfers have appropriate legal safeguards in place.

---

## Cookies

We use minimal cookies:
- **Session cookie** – Keeps you logged in
- **CSRF token** – Prevents cross-site attacks

We don't use tracking cookies or third-party analytics that track you across sites.

---

## Children's Privacy

supportpages.io is not intended for children under 16. We don't knowingly collect data from children. If you believe a child has provided us data, contact us and we'll delete it.

---

## Changes to This Policy

We may update this policy. When we do:
- We'll update the "Last updated" date
- For significant changes, we'll notify you by email or in-app notification
- Continued use after changes means you accept the new policy

You can see the history of this policy in our [GitHub repository](https://github.com/your-repo/docs/legal/privacy-policy.md).

---

## Contact Us

**Email:** privacy@supportpages.io

For GDPR inquiries, you can also contact your local data protection authority if you're unsatisfied with our response.

---

*This policy is written to be understood, not to protect us from you. If something is unclear, ask us.*
