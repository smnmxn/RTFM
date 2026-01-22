# Plan: Add/Delete Sections from Articles View

## Overview
Enable users to add and delete sections directly from the main Articles view, without navigating to a separate sections management page.

## Current State
- Sections sidebar in `_articles_panel.html.erb` displays sections with article counts
- Section CRUD exists in `SectionsController` but requires separate page navigation
- Pattern established with "New Article" modal for inline creation

## Proposed Changes

### 1. Add "+" Button to Sections Header

**File:** `app/views/projects/_articles_panel.html.erb`

Add a small "+" icon button next to the "Sections" heading in the left sidebar (line 24-26):

```erb
<div class="px-4 py-3 border-b border-gray-200 bg-gray-100 flex items-center justify-between">
  <h3 class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Sections</h3>
  <button type="button"
          data-action="section-modal#open"
          class="p-1 text-gray-400 hover:text-indigo-600 hover:bg-gray-200 rounded transition-colors"
          title="Add section">
    <%= heroicon "plus", options: { class: "w-4 h-4" } %>
  </button>
</div>
```

### 2. Create New Section Modal

**File:** `app/views/sections/_new_section_modal.html.erb` (new)

Similar pattern to `_new_article_modal.html.erb`:
- Name field (required)
- Description field (optional)
- Visible checkbox (default: true)
- Create/Cancel buttons

### 3. Create Stimulus Controller

**File:** `app/javascript/controllers/section_modal_controller.js` (new)

Handle:
- Modal open/close
- Form submission via fetch to `POST /projects/:slug/sections`
- Page refresh or Turbo Stream update on success

### 4. Add Delete Action to Section Rows

**File:** `app/views/projects/_articles_section_row.html.erb`

Two options:

**Option A: Hover-reveal delete button**
```erb
<button data-action="click->section-row#delete"
        class="opacity-0 group-hover:opacity-100 p-1 text-gray-400 hover:text-red-500">
  <%= heroicon "trash", options: { class: "w-4 h-4" } %>
</button>
```

**Option B: Context menu (right-click or kebab menu)**
- More actions possible (edit, reorder)
- Cleaner initial appearance

### 5. Update SectionsController for JSON Responses

**File:** `app/controllers/sections_controller.rb`

Modify `create` and `destroy` to handle JSON format:

```ruby
def create
  @section = @project.sections.build(section_params)
  @section.section_type = :custom
  @section.position = @project.sections.maximum(:position).to_i + 1

  if @section.save
    respond_to do |format|
      format.json { render json: { success: true, redirect_url: project_path(@project, anchor: "articles") } }
      format.turbo_stream { redirect_to project_sections_path(@project) }
      format.html { redirect_to project_sections_path(@project) }
    end
  else
    respond_to do |format|
      format.json { render json: { success: false, errors: @section.errors }, status: :unprocessable_entity }
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end

def destroy
  @section.articles.update_all(section_id: nil)
  @section.recommendations.update_all(section_id: nil)
  @section.destroy

  respond_to do |format|
    format.json { render json: { success: true } }
    format.turbo_stream { ... }
    format.html { redirect_to project_sections_path(@project) }
  end
end
```

### 6. Delete Confirmation

**Option A: Browser confirm dialog**
Simple `if (confirm('Delete section?'))` in JS

**Option B: Custom confirmation modal**
More consistent UX but more code

### 7. UI Refresh Strategy

After create/delete, either:
- **Turbo.visit()** - Simple, full page refresh with correct state
- **Turbo Stream** - Smoother, add/remove just the affected row

Recommend Turbo.visit() for simplicity since sections change infrequently.

## Files to Create/Modify

| File | Action |
|------|--------|
| `app/views/projects/_articles_panel.html.erb` | Modify - add + button, include modal |
| `app/views/sections/_new_section_modal.html.erb` | Create - modal template |
| `app/javascript/controllers/section_modal_controller.js` | Create - modal controller |
| `app/views/projects/_articles_section_row.html.erb` | Modify - add delete button |
| `app/controllers/sections_controller.rb` | Modify - JSON responses |

## Decisions Made

1. **Delete button style**: Kebab menu (three-dot menu) with Edit/Delete options
2. **Confirmation UX**: Browser `confirm()` dialog
3. **Scope**: Add and delete only (Edit option visible but links to existing edit page)
4. **Uncategorized**: Not deletable (it's a virtual grouping, not a real section)

## Implementation Steps

1. Create `section_modal_controller.js` - Stimulus controller for new section modal
2. Create `_new_section_modal.html.erb` - Modal template for adding sections
3. Create `section_menu_controller.js` - Stimulus controller for kebab dropdown menu
4. Modify `_articles_section_row.html.erb` - Add kebab menu with Edit/Delete options
5. Modify `_articles_panel.html.erb` - Add "+" button and include modal
6. Modify `sections_controller.rb` - Add JSON response support for create/destroy
