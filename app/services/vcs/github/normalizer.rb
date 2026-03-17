module Vcs
  module Github
    class Normalizer
      def self.repository(repo, installation = nil)
        {
          id: repo.id,
          full_name: repo.full_name,
          name: repo.name,
          owner: repo.owner.login,
          private: repo.private,
          description: repo.description,
          pushed_at: repo.pushed_at,
          html_url: repo.html_url,
          default_branch: repo.respond_to?(:default_branch) ? repo.default_branch : nil,
          homepage: repo.respond_to?(:homepage) ? repo.homepage : nil,
          installation_id: installation&.github_installation_id,
          installation_account: installation&.account_login
        }
      end

      def self.pull_request(pr)
        {
          number: pr.number,
          title: pr.title,
          html_url: pr.html_url,
          merged_at: pr.merged_at,
          merge_commit_sha: pr.merge_commit_sha,
          user: {
            login: pr.user.login,
            avatar_url: pr.user.avatar_url
          }
        }
      end

      def self.commit(commit)
        {
          sha: commit.sha,
          short_sha: commit.sha[0..6],
          message: commit.commit.message,
          title: commit.commit.message.split("\n").first.truncate(100),
          html_url: commit.html_url,
          committed_at: commit.commit.committer.date,
          author: {
            login: commit.author&.login || commit.commit.author.name,
            avatar_url: commit.author&.avatar_url || gravatar_url(commit.commit.author.email)
          }
        }
      end

      def self.gravatar_url(email)
        hash = Digest::MD5.hexdigest(email.to_s.downcase.strip)
        "https://www.gravatar.com/avatar/#{hash}?d=identicon"
      end
    end
  end
end
