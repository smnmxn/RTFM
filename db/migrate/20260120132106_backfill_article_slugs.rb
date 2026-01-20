class BackfillArticleSlugs < ActiveRecord::Migration[8.1]
  def up
    # Fail if any articles have no section - they must be assigned first
    orphaned_count = Article.where(section_id: nil).count
    if orphaned_count > 0
      raise "#{orphaned_count} articles have no section. Assign them to sections before running this migration."
    end

    # Generate slugs for all articles without one
    Article.where(slug: nil).find_each do |article|
      base_slug = article.title.to_s.parameterize
      base_slug = "article" if base_slug.blank?
      candidate = base_slug
      counter = 2

      # Check for existing slugs in the same section
      while Article.where(section_id: article.section_id, slug: candidate).where.not(id: article.id).exists?
        candidate = "#{base_slug}-#{counter}"
        counter += 1
      end

      article.update_column(:slug, candidate)
    end
  end

  def down
    Article.update_all(slug: nil)
  end
end
