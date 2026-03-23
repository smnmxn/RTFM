module Vcs
  module Bitbucket
    class Normalizer
      def self.repository(data, connection = nil)
        {
          id: data["uuid"] || data["full_name"],
          full_name: data["full_name"],
          name: data["name"],
          owner: data.dig("workspace", "slug") || data.dig("owner", "username") || data["full_name"]&.split("/")&.first,
          private: data["is_private"],
          description: data["description"],
          pushed_at: data["updated_on"],
          html_url: data.dig("links", "html", "href"),
          default_branch: data.dig("mainbranch", "name"),
          homepage: data["website"],
          installation_id: connection&.id,
          installation_account: connection&.workspace_slug,
          provider: "bitbucket"
        }
      end

      def self.pull_request(data)
        {
          number: data["id"],
          title: data["title"],
          html_url: data.dig("links", "html", "href"),
          merged_at: data["updated_on"],
          merge_commit_sha: data.dig("merge_commit", "hash"),
          user: {
            login: data.dig("author", "display_name") || data.dig("author", "nickname"),
            avatar_url: data.dig("author", "links", "avatar", "href")
          }
        }
      end

      def self.commit(data)
        sha = data["hash"]
        message = data["message"] || ""
        author_raw = data.dig("author", "raw") || ""
        # Extract name from "Name <email>" format
        author_name = author_raw.split("<").first&.strip || author_raw

        {
          sha: sha,
          short_sha: sha[0..6],
          message: message,
          title: message.split("\n").first.to_s.truncate(100),
          html_url: data.dig("links", "html", "href"),
          committed_at: data["date"],
          author: {
            login: data.dig("author", "user", "display_name") || author_name,
            avatar_url: data.dig("author", "user", "links", "avatar", "href") || gravatar_url(author_raw)
          }
        }
      end

      def self.gravatar_url(author_raw)
        # Extract email from "Name <email>" format
        email = author_raw[/<(.+?)>/, 1].to_s
        hash = Digest::MD5.hexdigest(email.downcase.strip)
        "https://www.gravatar.com/avatar/#{hash}?d=identicon"
      end
    end
  end
end
