---
title: "Automated Outreach with OpenClaw. No Sales Team."
date: 2026-03-03
author: "Simon Moxon"
excerpt: "175 qualified prospects in a weekend. Here's the exact process, prompts, and tools."
description: "How I used OpenClaw to qualify 175 SaaS prospects, enrich them with founder details, and set up automated outreach in 48 hours. The exact prompts, code, and process for solo founder prospecting with AI."
keywords: "AI prospecting, OpenClaw, automated outreach, solo founder sales, SaaS lead generation, AI cold email"
published: false
---

Here's something it took me 15 years to learn: the hard part of prospecting isn't finding leads. It's getting them to read past the first line.

I've hired SDRs who could fill a pipeline with hundreds of names. Bought lead lists with thousands. Built email sequences that sent automatically for months. The response rate was always the same: terrible.

The problem was never volume. It was specificity. Generic outreach to a broad list gets deleted. A narrow wedge to the exact right person gets read.

The lesson: know precisely who you want and why, then reach only those people with something they actually care about. Everything else is noise.

I used to need a team to do this properly. The research, the qualification, the enrichment, the personalisation - it took people and time. Now I can do it in a weekend with AI.

This weekend I qualified 175 prospects, enriched them with founder details, and set up automated outreach. Most of the execution was handled by OpenClaw, an AI agent I've been running for the last few months. My job was direction and judgment.

Here's exactly how it worked.

## The Setup

**Tools:**
- [OpenClaw](https://openclaw.ai) - AI agent that runs locally, can spawn subagents for parallel work
- Brave Search API - web research ($5/month for 2000 queries)
- Notion - as the CRM
- Gmail API via `gog` CLI - for sending

**My time:** Maybe 2-3 hours of actual input over the weekend. The rest was the AI working while I did other things.

## Step 1: Define the ICP

This part was all me. You need to know who you're looking for before you can instruct an AI to find them.

```markdown
## Ideal Customer Profile

- Web-based SaaS (not mobile apps, desktop, or developer tools)
- UK-based company
- Small team (1-10 people)  
- Non-technical end users (not selling to developers)
- Complex product with many features (high support burden)
- Poor or non-existent documentation
```

This became the qualification criteria I gave to OpenClaw later.

## Step 2: Source Raw Prospects

I already had a list of ~250 UK tech companies from a startup directory. OpenClaw had previously scraped Product Hunt for recent SaaS launches. Combined: ~330 raw companies in a JSON file.

The quality was mixed. Mobile apps, developer tools, dead companies. I needed to filter down to the ones that actually matched my ICP.

## Step 3: Qualification and Enrichment

This is where OpenClaw earned its keep.

I asked it to enrich the 173 prospects that were missing data. The instruction was simple:

> "Enrich all qualified leads before syncing to Notion. Batch them up so we don't hit rate limits."

OpenClaw proposed batching into groups of 10, running 5 subagents in parallel. Each agent would:

- Visit the company website
- Find the founder's name (LinkedIn, about page, press)
- Find their email (pattern matching, Hunter.io patterns)
- Check what docs platform they use (Intercom, Zendesk, GitBook, none)
- Note how actively they're shipping

I approved the approach and it got to work. Each batch took about 5 minutes. The whole thing ran for about 4 hours with minimal intervention from me.

**The prompt each subagent used:**

```
Enrich this prospect with founder contact details.

Company: [name]
Website: [url]

Find:
1. Founder/CEO name (LinkedIn, website about page, press)
2. Founder email (try firstname@domain, first.last@domain, 
   check Hunter.io patterns)
3. LinkedIn profile URL
4. What docs/help platform do they use? 
5. Are they actively shipping? (changelog, GitHub, recent updates)

Return as JSON.
```

Mid-way through, we hit an API rate limit. I updated the Brave API key and restarted. That was the extent of my troubleshooting.

**Result:** 173 prospects fully enriched with founder names, personal emails, LinkedIn profiles, current docs platform, and shipping frequency.

## Step 4: Sync to Notion

OpenClaw wrote a Python script to push all 173 prospects into a Notion database, then ran it. I now had a proper CRM sortable by fit score and filterable by outreach status.

```python
# The sync script OpenClaw wrote
def create_prospect(prospect):
    notion.pages.create(
        parent={"database_id": DATABASE_ID},
        properties={
            "Name": {"title": [{"text": {"content": prospect["company"]}}]},
            "Website": {"url": prospect["website"]},
            "Founder": {"rich_text": [{"text": {"content": prospect["founder_name"]}}]},
            "Email": {"email": prospect["founder_email"]},
            "Fit Score": {"number": prospect["fit_score"]},
            "Status": {"select": {"name": "Not Contacted"}}
        }
    )
```

## Step 5: The Outreach Template

This was collaborative. OpenClaw drafted, I directed.

The first draft was too SDR-ish. "I came across your company" vibes. I pushed back:

> "This reads like every cold email I delete without reading. I want a trade, not a pitch. Quid pro quo."

Several iterations later, we landed on something that felt right. The key changes I made:

- **Killed the fake compliments.** No "I love what you're doing with X."
- **Led with what they get.** Free AI-powered help centre.
- **Was specific about why them.** UK SaaS, non-technical users, heavy support burden.
- **Made it a fair swap.** They get a free product, I get feedback.

**The final template:**

```
Hi [FOUNDER_NAME],

We're launching SupportPages.io this summer. It's an AI-powered 
help centre that connects directly to your source code. When you 
add a feature or make an update, it writes the help docs for you.

Your customer-facing docs stay up to date without anyone having 
to write them.

It's built and working with a few products already. Before launch, 
I'm looking for UK SaaS products with non-technical end users and 
a heavy support burden to test it with. [COMPANY] fits that perfectly.

You'd get a full AI-powered help centre for free, and hopefully 
never have to write an article again.

You can see more here: https://supportpages.io

Interested?

Simon
```

## Step 6: Automated Sending

I asked OpenClaw to set up automated outreach: two emails per hour, 8am-5pm, Monday to Friday. Slow enough to warm up the domain, fast enough to get through the list.

It wrote the send script, set up the cron job, added bounce detection, and connected everything to Notion for status tracking.

```bash
# The cron schedule
0,30 8-17 * * 1-5 python send_batch.py --count 2
```

I sent the first 5 manually to test. One bounced. I suggested an alternative email pattern and OpenClaw retried. It went through.

Since Monday morning, the cron has been running automatically. I check in occasionally to review any bounces.

## The Split: What I Did vs What the AI Did

| Task | Me | OpenClaw |
|------|:---:|:--------:|
| Define ICP | ✓ | |
| Source raw prospects | ✓ | |
| Design enrichment strategy | | ✓ |
| Run enrichment (173 prospects) | | ✓ |
| Write and run Notion sync | | ✓ |
| Draft outreach email | | ✓ |
| Direct tone and messaging | ✓ | |
| Approve final template | ✓ | |
| Write send automation | | ✓ |
| Set up cron and monitoring | | ✓ |
| Ongoing sends | | ✓ |

My actual contribution was knowing what I wanted, giving clear direction, and making judgment calls on quality. The AI handled everything else.

## The Numbers

| Metric | Count |
|--------|-------|
| Raw prospects | ~330 |
| Qualified | 175 |
| Fully enriched | 173 |
| Emails sent (day 2) | 11 |
| Bounces | 1 |
| Hours of my time | ~3 |

## What This Used to Cost

In 2015, I hired our first SDR at Meetupcall. 

- Salary: £28k/year
- Ramp time: 3 months before productive
- Tools (Outreach, LinkedIn Sales Nav, lead lists): £500/month
- Management overhead: 4+ hours/week

Once ramped, they'd qualify maybe 50 leads per week.

This weekend: 175 qualified, enriched prospects with automated outreach running. Cost: $5 API upgrade and a few hours of direction.

## How to Do This Yourself

The process isn't complicated:

1. **Know your ICP cold.** Write it down. Be specific. If you can't describe your ideal customer in one paragraph, the AI can't find them.

2. **Start with a raw list.** Startup directories, Product Hunt, industry lists. Quality doesn't matter yet.

3. **Use AI for the grunt work.** Qualification, enrichment, research. Batch it, parallelise it, let it run.

4. **Keep the human judgment for messaging.** The AI can draft, but you need to feel whether it sounds like you or like a robot.

5. **Automate the boring parts.** Sending, bounce checking, CRM updates. Once it's set up, it runs itself.

The tools are all available. OpenClaw is free. The APIs are cheap. The rest is just being clear about what you want.

## What's Next

The emails are running. I'll update this post with open rates, reply rates, and what actually converts to calls.

---

## About the Author

**Simon Moxon** has been building SaaS companies since 2009. He's scaled teams to 20+ people, hit £2m ARR, and learned most of the lessons the hard way. Now he's building [SupportPages.io](https://supportpages.io) - help docs that write themselves when you ship code. He writes about what's changed in SaaS and what hasn't.

[Twitter](https://twitter.com/simonmoxon) · [LinkedIn](https://www.linkedin.com/in/smoxon/)
