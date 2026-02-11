# Data Processing Agreement

**Last updated:** February 11, 2026

---

This Data Processing Agreement ("DPA") forms part of the agreement between **Surface Layer Limited** (Company No. 17026012), trading as supportpages.io ("Processor", "we", "us"), with its registered office at 128 City Road, London, United Kingdom, EC1V 2NX, and the entity agreeing to these terms ("Controller", "Customer", "you") for the use of supportpages.io services.

This DPA reflects the requirements of the EU General Data Protection Regulation (GDPR), specifically Article 28.

---

## 1. Definitions

**Personal Data** means any information relating to an identified or identifiable natural person.

**Processing** means any operation performed on personal data, including collection, storage, use, disclosure, and deletion.

**Controller** means the entity that determines the purposes and means of processing personal data. That's you.

**Processor** means the entity that processes personal data on behalf of the controller. That's us.

**Sub-processor** means any third party engaged by us to process personal data on your behalf.

**Data Subject** means the individual whose personal data is processed.

---

## 2. Scope and Purpose

### 2.1 What This Covers
This DPA applies to personal data that we process on your behalf when you use supportpages.io to:
- Analyze code repositories
- Generate documentation
- Host published documentation

### 2.2 Roles
- **You are the Controller** of personal data in your repositories and generated content
- **We are the Processor** acting on your instructions to provide the service

### 2.3 Processing Purpose
We process personal data solely to provide supportpages.io services as described in our Terms of Service. We don't process your data for our own purposes.

---

## 3. Data Categories

We may process the following categories of personal data on your behalf:

| Category | Examples | Source |
|----------|----------|--------|
| Developer identifiers | Names, emails in code/commits | Your repositories |
| Commit metadata | Author names, commit messages | GitHub webhooks |
| Documentation content | Any personal data in generated docs | AI-generated from your code |

**Note:** The actual personal data processed depends on what's in your repositories. We don't control what data you put in your code.

---

## 4. Processing Instructions

### 4.1 Your Instructions
We process personal data only according to your documented instructions, which include:
- The Terms of Service you agreed to
- Configuration choices you make in the service
- Specific requests you make via support

### 4.2 Notification
If we believe an instruction violates GDPR or other data protection laws, we'll notify you before processing (unless prohibited by law).

### 4.3 No Other Processing
We won't process your personal data for any purpose other than providing the service, unless:
- Required by law (and we'll tell you, if allowed)
- You give us additional instructions

---

## 5. Security Measures

We implement appropriate technical and organizational measures to protect personal data:

### 5.1 Technical Measures
- **Encryption in transit:** TLS 1.2+ for all connections
- **Encryption at rest:** Database encryption
- **Access controls:** Role-based access, authentication required
- **Infrastructure:** EU-based servers (Hetzner, Finland)

### 5.2 Organizational Measures
- **Employee access:** Limited to those who need it
- **Confidentiality:** Staff bound by confidentiality obligations
- **Training:** Security awareness for team members

### 5.3 Code Handling
- Code is processed in isolated, ephemeral environments
- Environments are destroyed after each analysis
- Your source code is never stored in our database
- Only generated documentation is retained

See our [Security Overview](/legal/security) for more details.

---

## 6. Sub-processors

### 6.1 Current Sub-processors
We use the following sub-processors:

| Sub-processor | Purpose | Location |
|---------------|---------|----------|
| Anthropic | AI analysis | USA |
| GitHub | Code access, webhooks | USA |
| Hetzner | Hosting infrastructure | Finland (EU) |
| Cloudflare | DNS, custom domains | Global |
| Rollbar | Error monitoring | USA |

See our [Sub-processor List](/legal/subprocessors) for the current list.

### 6.2 Sub-processor Changes
Before adding or changing sub-processors:
1. We'll update our sub-processor list
2. We'll notify you via email (if you've opted in) or by updating our website
3. You'll have 30 days to object

### 6.3 Objections
If you object to a new sub-processor:
- Contact us to discuss concerns
- If we can't resolve the concern, you may terminate affected services
- Termination for this reason won't incur early termination fees

### 6.4 Sub-processor Obligations
Our sub-processors are bound by contracts that impose data protection obligations equivalent to this DPA.

---

## 7. Data Subject Rights

### 7.1 Your Responsibility
You're responsible for responding to data subject requests (access, deletion, etc.) for personal data in your repositories and content.

### 7.2 Our Assistance
We'll help you respond to data subject requests by:
- Providing tools to export and delete data
- Responding to requests you forward to us
- Providing information about our processing

### 7.3 Direct Requests
If a data subject contacts us directly about their data in your content:
- We'll direct them to you (unless legally required otherwise)
- We'll notify you of the request
- We won't respond on your behalf without your instruction

---

## 8. Breach Notification

### 8.1 Our Commitment
If we become aware of a personal data breach affecting your data, we will:
- Notify you without undue delay (and within 72 hours)
- Provide information about the nature of the breach
- Describe likely consequences
- Describe measures taken or proposed

### 8.2 What We'll Tell You
Our breach notification will include (to the extent known):
- Categories of data affected
- Approximate number of records affected
- Contact point for more information
- Measures to address the breach

### 8.3 Your Obligations
You're responsible for notifying data protection authorities and affected individuals as required by law. We'll assist as needed.

---

## 9. Audits

### 9.1 Your Rights
You may audit our compliance with this DPA. This can include:
- Requesting documentation of our security measures
- Requesting results of third-party audits or certifications
- Conducting or commissioning your own audit

### 9.2 Audit Process
To conduct an audit:
1. Give us 30 days written notice
2. Audits will be during business hours
3. Audits won't unreasonably interfere with our operations
4. You'll bear audit costs (unless we're found non-compliant)
5. Auditors must sign confidentiality agreements

### 9.3 Information Requests
We'll provide reasonable information to demonstrate compliance, such as:
- Documentation of security measures
- Summaries of audit results
- Certifications we hold

---

## 10. Data Deletion

### 10.1 During the Service
You can delete data through the service interface:
- Delete individual articles
- Delete projects
- Delete your account

### 10.2 Upon Termination
When you terminate service:
- We'll delete your personal data within 30 days
- Some data may remain in backups for up to 30 additional days
- We'll provide data export upon request before deletion

### 10.3 Exceptions
We may retain data if:
- Required by law
- Needed to establish, exercise, or defend legal claims
- Anonymized for aggregate analytics

---

## 11. International Transfers

### 11.1 Primary Storage
Your data is stored in the EU (Finland).

### 11.2 Sub-processor Transfers
When data is transferred to sub-processors outside the EU:
- We ensure appropriate safeguards (Standard Contractual Clauses)
- We have Data Processing Agreements with all sub-processors
- See Section 6 for sub-processor locations

### 11.3 Transfer Mechanisms
For US-based sub-processors, we rely on:
- EU Standard Contractual Clauses (SCCs)
- EU-US Data Privacy Framework (where certified)

---

## 12. Liability

### 12.1 Our Responsibility
We're liable for damage caused by processing that violates:
- This DPA
- GDPR processor obligations
- Your lawful instructions

### 12.2 Limitations
Liability is limited as set forth in our Terms of Service, except:
- As prohibited by law
- For gross negligence or willful misconduct

---

## 13. Term and Termination

### 13.1 Term
This DPA is effective when you start using supportpages.io and continues until you stop.

### 13.2 Survival
Provisions that should survive termination (like data deletion obligations and liability) will continue.

---

## 14. Changes

We may update this DPA to reflect:
- Changes in law or regulation
- Changes in our processing activities
- Improved security measures

We'll notify you of material changes and provide 30 days to object before changes take effect.

---

## 15. Contact

For DPA-related inquiries:

**Email:** dpa@supportpages.io

---

## Annex A: Technical and Organizational Measures

### A.1 Access Control
- Authentication required for all access
- Role-based permissions
- Session management with secure tokens

### A.2 Encryption
- TLS 1.2+ for data in transit
- Database encryption for data at rest
- Encrypted backups

### A.3 Infrastructure Security
- EU-based hosting (Hetzner, Finland)
- Firewall protection
- Regular security updates

### A.4 Data Minimization
- Code diffs processed temporarily
- Raw code not stored long-term
- Only necessary data retained

### A.5 Incident Response
- Monitoring for security events
- Defined incident response procedures
- Breach notification process

---

*This DPA establishes our commitments as your data processor. If you have questions or need a signed copy for your records, contact us.*
