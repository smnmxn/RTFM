# Visitor Tracking Implementation

## Overview

Implemented a dedicated `visitors` table to track unique visitors across sessions with persistent identity, attribution, and engagement data. This replaces the previous approach where visitor metadata was duplicated on every analytics event.

## What Was Built

### 1. Visitor Model (`app/models/visitor.rb`)

A new model that stores one record per unique visitor (identified by UUID cookie).

**Key Features:**
- First-touch UTM attribution (source, medium, campaign, term, content)
- Initial referrer tracking (URL and host)
- Device/browser/OS metadata (enriched over time)
- Identity tracking (email, name, user_id)
- Activity counters (total_page_views, total_events)
- Timestamps (first_seen_at, last_seen_at, identified_at)

**Scopes:**
- `returning` - Visitors with >1 page view
- `new_visitors` - Visitors with exactly 1 page view
- `identified` - Visitors with email address
- `anonymous` - Visitors without email
- `from_source(source)` - Visitors from specific UTM source
- `active_since(date)` - Visitors active since date

**Helper Methods:**
- `record_activity!(event_type:, ...)` - Update counters and metadata
- `identify!(email:, name:, user_id:)` - Capture visitor identity
- `returning_visitor?` - Check if visitor has returned
- `identified?` - Check if visitor has been identified
- `converted?` - Check if visitor has signed up

### 2. Database Schema

**Created `visitors` table:**
```ruby
create_table :visitors do |t|
  # Core identification
  t.string :visitor_id, limit: 36, null: false, index: { unique: true }

  # Attribution (first touch)
  t.string :utm_source
  t.string :utm_medium
  t.string :utm_campaign
  t.string :utm_term
  t.string :utm_content
  t.string :initial_referrer_url
  t.string :initial_referrer_host
  t.string :initial_landing_page

  # Last known information
  t.string :last_ip_address
  t.string :last_user_agent, limit: 512
  t.string :device_type
  t.string :browser_family
  t.string :os_family

  # Identity
  t.string :email
  t.string :name
  t.integer :user_id
  t.datetime :identified_at

  # Activity tracking
  t.datetime :first_seen_at, null: false
  t.datetime :last_seen_at, null: false
  t.integer :total_page_views, default: 0, null: false
  t.integer :total_events, default: 0, null: false

  t.timestamps
end
```

**Indexes:**
- `visitor_id` (unique)
- `last_seen_at`
- `first_seen_at`
- `email`
- `user_id`

### 3. Updated Components

#### Trackable Concern (`app/controllers/concerns/trackable.rb`)
- Added `ip_address: request.remote_ip` to tracking data
- IP address now captured on every page view

#### RecordAnalyticsEventJob (`app/jobs/record_analytics_event_job.rb`)
- Creates Visitor record on first event with first-touch attribution
- Updates Visitor record on subsequent events
- Increments activity counters
- Enriches metadata over time (IP, user agent, device/browser/OS)
- Handles race conditions with retry on RecordNotUnique

#### AnalyticsEvent Model (`app/models/analytics_event.rb`)
- Added `belongs_to :visitor` association (optional)
- Events now link to Visitor records via visitor_id

#### SessionsController (`app/controllers/sessions_controller.rb`)
- Added `identify_visitor` method
- Called on both new user signup and existing user login
- Links anonymous visitor to authenticated user account

#### WaitlistController (`app/controllers/waitlist_controller.rb`)
- Added `identify_visitor_with_email` method
- Called when user submits email for waitlist
- Captures email before full signup

#### AnalyticsSummaryService (`app/services/analytics_summary_service.rb`)
- Added `visitor_breakdown` method with metrics:
  - Total visitors
  - New visitors (1 page view)
  - Returning visitors (>1 page view)
  - Identified visitors (have email)
  - Anonymous visitors (no email)
  - Converted visitors (have user_id)
  - Average pages per visitor
- Updated `device_breakdown` and `browser_breakdown` to query from Visitor table
- Updated `utm_breakdown` and `utm_content_breakdown` to show first-touch attribution from Visitor

#### Analytics View (`app/views/analytics/_public.html.erb`)
- Added "Visitor Insights" card showing new/returning/identified breakdown
- Updated UTM sections to show "visitors" instead of "views" (now showing unique attribution)

### 4. Migrations

**Migration 1: CreateVisitors**
- Created visitors table with full schema
- Added all indexes

**Migration 2: MigrateExistingAnalyticsDataToVisitors**
- Backfills visitors table from existing analytics_events
- Groups events by visitor_id
- Uses first event for attribution
- Uses last event for current metadata
- Calculates total_events and total_page_views

## Data Flow

### New Visitor Flow
1. User visits site → Cookie doesn't exist
2. `ensure_visitor_id` generates UUID, sets cookie
3. `track_page_view` captures UTM params, IP, user agent, referrer
4. `RecordAnalyticsEventJob` creates Visitor record with first-touch attribution
5. AnalyticsEvent created and linked to visitor_id
6. Visitor counters initialized (total_page_views: 1, total_events: 1)

### Returning Visitor Flow
1. User visits site → Cookie exists
2. `ensure_visitor_id` returns existing UUID
3. `track_page_view` captures current IP, user agent
4. `RecordAnalyticsEventJob` finds existing Visitor
5. AnalyticsEvent created
6. Visitor record updated:
   - `last_seen_at` → current time
   - `last_ip_address` → current IP (may have changed)
   - `last_user_agent` → current user agent (may have changed)
   - `device_type`, `browser_family`, `os_family` → updated if changed
   - `total_page_views` → incremented
   - `total_events` → incremented

### Visitor Identification Flow
1. Anonymous visitor browses site (tracked by cookie)
2. User signs up for waitlist or logs in with GitHub
3. Controller calls `visitor.identify!(email: user.email, name: user.name, user_id: user.id)`
4. Visitor record updated:
   - `email` → user's email
   - `name` → user's name
   - `user_id` → user's ID (if logged in)
   - `identified_at` → timestamp of first identification
5. Now we can see full journey: anonymous → identified → converted

## Benefits

1. **Single Source of Truth**: All visitor metadata in one place
2. **Enrichment**: Visitor profiles improve over time
3. **Attribution**: Clear first-touch UTM tracking (not diluted by subsequent visits)
4. **Performance**: No need to deduplicate visitor_id on every query
5. **Return Visitor Analysis**: Easy to identify and analyze return visits
6. **IP Tracking**: Can add geolocation, fraud detection later
7. **Identity Tracking**: Link anonymous visitors to known users
8. **Full Journey**: See complete visitor journey from first visit to signup
9. **Email Marketing**: Export identified visitors for outreach campaigns

## Testing

Created comprehensive test suite:

**Test Files:**
- `test/models/visitor_test.rb` (26 tests)
  - Validation tests
  - Association tests
  - Scope tests
  - Method tests (record_activity!, identify!, etc.)

**Existing Tests Updated:**
- AnalyticsEvent model tests still pass
- RecordAnalyticsEventJob tests still pass

**All visitor tracking tests passing:** ✅

## Usage Examples

### Query Visitor Data

```ruby
# Get all returning visitors from LinkedIn in last 7 days
Visitor.active_since(7.days.ago)
       .from_source('linkedin')
       .returning

# Get identified visitors who haven't converted yet
Visitor.identified.where(user_id: nil)

# Get average pages per visitor
Visitor.average(:total_page_views)
```

### Track Visitor Identity

```ruby
# When user submits waitlist form
visitor = Visitor.find_by(visitor_id: cookies[:_sp_vid])
visitor&.identify!(email: params[:email])

# When user logs in
visitor = Visitor.find_by(visitor_id: cookies[:_sp_vid])
visitor&.identify!(
  email: user.email,
  name: user.name,
  user_id: user.id
)
```

### View Analytics

The analytics dashboard at `/analytics` now shows:
- Visitor breakdown (new vs returning, identified vs anonymous)
- First-touch UTM attribution (shows unique visitors, not total views)
- Device and browser breakdown (from visitor profiles)
- Returning visitor metrics

## Future Enhancements

Potential additions:
1. Geolocation based on IP address
2. Visitor journey timeline view
3. Email export for marketing campaigns
4. Advanced segmentation (e.g., "high-intent visitors")
5. Visitor scoring based on engagement
6. A/B test assignment tracking
7. Session replay integration
8. Fraud detection based on patterns

## Files Created

- `app/models/visitor.rb` - Visitor model with associations and scopes
- `db/migrate/20260304135330_create_visitors.rb` - Create visitors table
- `db/migrate/20260304135415_migrate_existing_analytics_data_to_visitors.rb` - Backfill data
- `test/models/visitor_test.rb` - Comprehensive test suite
- `docs/visitor-tracking-implementation.md` - This documentation

## Files Modified

- `app/controllers/concerns/trackable.rb` - Added IP address tracking
- `app/jobs/record_analytics_event_job.rb` - Create/update Visitor records
- `app/models/analytics_event.rb` - Added visitor association
- `app/controllers/sessions_controller.rb` - Identify visitor on login
- `app/controllers/waitlist_controller.rb` - Identify visitor on waitlist signup
- `app/services/analytics_summary_service.rb` - Query Visitor table for breakdowns
- `app/views/analytics/_public.html.erb` - Display visitor insights

## Configuration Changes

None - the implementation uses existing infrastructure.

## Environment Variables

None required - IP address tracking uses `request.remote_ip` which is automatically available.

## Deployment Notes

The migrations can be run safely in production:
1. CreateVisitors migration is instant (just schema change)
2. Backfill migration may take time if there are many existing events (runs in up method)
3. No downtime required - old and new systems work side-by-side during transition
4. Analytics events continue to store visitor metadata for now (can be removed in future migration)

## Performance Considerations

- Visitor lookups are indexed by visitor_id (UUID)
- No additional N+1 queries introduced
- Analytics queries now use JOIN or subqueries to Visitor table (still performant)
- Counters are updated in-place (no recalculation needed)

## Known Limitations

1. Visitor tracking relies on cookies (doesn't work if cookies disabled)
2. Same user on different devices = different visitors (by design)
3. Clearing cookies creates new visitor record
4. IP address may change between visits (normal for mobile users)

These are acceptable trade-offs for cookied-based visitor tracking.
