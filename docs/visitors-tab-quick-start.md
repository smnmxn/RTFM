# Visitors Tab - Quick Start Guide

## Accessing the Visitors Tab

1. Navigate to `/analytics` (requires admin login)
2. Click the **"Visitors"** tab
3. Select time period (24h, 7d, 30d, 90d)

## What You'll See

### Visitors List Page

**Main Table Columns:**
- **Visitor** - Unique ID + status badge (New/Returning)
- **Identity** - Email, name, and conversion status
- **Page Views** - Total pages visited
- **Events** - All tracked events
- **Source** - UTM attribution (where they came from)
- **Device** - Device type, browser, OS
- **First/Last Seen** - Activity timeline
- **Actions** - "View" button for details

**Status Badges:**
- 🟢 **New** - First visit
- 🔵 **Returning** - Multiple visits
- 🟡 **Identified** - Has email (from waitlist)
- 🟣 **Converted** - Signed up as user

### Visitor Detail Page

Click "View" on any visitor to see:

1. **Summary Cards** - Quick stats (page views, events, dates)
2. **Identity** - Email, name, conversion status
3. **Attribution** - How they found you (UTM params, referrer)
4. **Technical** - Device, browser, OS, IP
5. **Event Summary** - Breakdown by event type
6. **Activity Timeline** - Last 100 events with full details

## Common Use Cases

### 1. Find High-Value Visitors
**Filter:** Last 7 days
**Look for:** Returning + Identified + Multiple page views
**Action:** Review journey, note email for follow-up

### 2. Track Campaign Performance
**Filter:** Last 30 days
**Look at:** Source column for your campaign UTM
**Click:** Into specific visitors to see their journey
**Analyze:** Did they convert? What pages did they visit?

### 3. Identify Hot Leads
**Look for:**
- Returning visitors (multiple visits = interest)
- Identified visitors with emails
- High page view counts (8+ pages)
- Video engagement events
- Not yet converted (opportunity to reach out)

### 4. Debug Conversion Issues
**Find:** Visitors who got far but didn't convert
**Check:**
- Where did they drop off?
- What pages did they visit most?
- Did they watch videos?
- Any error events?

### 5. Export Emails for Marketing
**Find:** Identified visitors from specific campaign
**Note:** Email addresses shown in Identity column
**Use:** For targeted email follow-up

## Quick Tips

✅ **Start with most recent** - Default sort is by last_seen_at (newest first)

✅ **Check returning visitors** - Higher intent, more likely to convert

✅ **UTM attribution is first-touch** - Shows original source, not most recent

✅ **100 events shown** - Full timeline of visitor behavior

✅ **Anonymous by default** - Only identified after email capture or signup

✅ **Real-time updates** - Last seen updates with each visit

## Example Workflows

### Workflow 1: Daily Lead Review (5 minutes)
1. Go to Visitors tab → 24h filter
2. Scan for Identified badges (🟡)
3. Click "View" on high page view counts
4. Export emails of engaged visitors
5. Follow up via email

### Workflow 2: Campaign Analysis (15 minutes)
1. Go to Visitors tab → 30d filter
2. Look for visitors with your campaign UTM
3. Click into 5-10 sample visitors
4. Note patterns:
   - Common landing pages
   - Average page views before conversion
   - Drop-off points
5. Use insights to optimize campaign

### Workflow 3: Product Insights (10 minutes)
1. Go to Visitors tab → 7d filter
2. Filter for Returning visitors
3. Review which pages they visit most
4. Check video engagement
5. Identify popular content areas

## Navigation

**From:** `/analytics?tab=visitors` (list)
**To:** `/analytics/visitors/:id` (detail)
**Back:** "← Back to Visitors" link at top

## Performance Notes

- **50 visitors per page** - Uses pagination for fast loading
- **Filters by time period** - Only loads visitors from selected range
- **100 events max** - Most recent events on detail page
- **Real-time data** - Updates as visitors interact with site

## Need Help?

- **Full docs:** See `docs/visitors-tab-implementation.md`
- **Visitor tracking:** See `docs/visitor-tracking-implementation.md`
- **Issues:** Report at GitHub issues

## Quick Stats to Check

Monitor these on the Visitors tab:

📊 **Conversion Rate** = (Converted visitors / Total visitors) × 100
📊 **Identification Rate** = (Identified visitors / Total visitors) × 100
📊 **Return Rate** = (Returning visitors / Total visitors) × 100
📊 **Avg Pages/Visitor** = Total page views / Total visitors

Higher numbers = Better engagement! 🎯
