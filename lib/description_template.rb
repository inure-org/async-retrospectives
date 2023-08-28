require 'date'
require 'erb'

require './lib/inure_api'

class DescriptionTemplate
    private attr_reader :team, :release, :api_client

    def initialize(team, release, api_client:)
        @team = team
        @release = release
        @api_client = api_client
    end

    def issue_query_prefix
        # https://docs.gitlab.com/ee/api/issues.html
        if @team.query_all_groups?
            'issues?scope=all&'
        else
            'groups/inure-org/issues?' # queries padrões de inure-org apenas
        end
    end

    def merge_request_query_prefix
        # https://docs.gitlab.com/ee/api/merge_requests.html
        if @team.query_all_groups?
            'merge_requests?scope=all&'
        else
            'groups/inure-org/merge_requests?' # queries padrões de inure-org apenas
        end
    end

    def get_with_auth?
        # padrão é false - isso é setado como true quando todos os grupos estiverem consultados
        # têm algumas queries nas quais a autenticação esteja sempre setada como true (counts, sums, follow-ups)
        @team.query_all_groups? ? true : false
    end

    def template_issue_url_prefix
        if @team.query_all_groups?
            'dashboard/issues?scope=all&' # contas para outros projetos
        else
            'groups/inure-org/-/issues?' # queries padrões de inure-org apenas
        end
    end

    def result_with_hash(hash)
        binding_hash = {
            team: team,
            release: release['title'],
            due_date: Date.today.next_month.strftime('%Y-%m-26')
        }

        hash[:mention_owners] = self.mention_team_owners

        if hash[:updating_description]
            binding_hash.merge!(
                due_date: Date.today.strftime('%Y-%m-26'),
                deliverables: deliverables,
                features: features,
                bugs: bugs,
                issues: issues,
                issue_count: issue_count,
                total_weight: total_weight,
                merge_request_count: merge_request_count,
                slipped: slipped,
                follow_up: follow_up,
                unplanned: unplanned,
                current_retrospective: current_retrospective,
                issue_url_prefix: hash[:query_all_groups] === true ? 'dashboard/issues?scope=all&' : 'groups/inure-org/-/issues?',
                vsa_url_prefix: 'groups/inure-org/-/analytics/value_stream_analytics?',

                release_start_date: release.fetch('start_date', nil),
                release_due_date: release.fetch('due_date', nil)
            )

            if team.additional_label
                hash[:additional_label] = team.additional_label
                hash[:issues_with_additional_label] = issues_with_additional_label
            end
        end

        binding_hash.merge!(hash)

        include_template = lambda do |filename|
            load_template(filename).result_with_hash(binding_hash)
        end

        binding_hash[:include_template] = include_template

        template.result_with_hash(binding_hash)
    end

    def current_issue_url
        current_retrospective&.fetch('web_url') || 'http://does.not/exist'
    end

    def current_api_path
        "projects/gl-retrospectives%2F#{team.project}/issues/#{current_retrospective&.fetch('iid') || -1}"
    end

    def current_retrospectives_api_path(extra_labels = [])
        labels = ['retrospective'].concat(extra_labels)

        "projects/gl-retrospectives%2F#{team.project}/issues?labels=#{labels.join(',')}&state=opened&search=#{release['title']}"
    end

    def deliverables
        @deliverables ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},Deliverable&state=closed&milestone=#{release['title']}", auth: get_with_auth?)
    end

    def features
        @features ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},type::feature&state=closed&milestone=#{release['title']}", auth: get_with_auth?)
    end
    
    def bugs
        @bugs ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},type::bug&state=closed&milestone=#{release['title']}", auth: get_with_auth?)
    end
    
    def slipped
        @slipped ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},missed%3A#{release['title']}", auth: get_with_auth?)
    end
    
    def follow_up
        @follow_up ||=
            api_client.get("projects/gl-retrospectives%2F#{team.project}/issues?labels=follow-up&state=opened", auth: true)
    end
    
    def unplanned
        @unplanned ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},Unplanned&milestone=#{release['title']}", auth: get_with_auth?)
    end

    def issues_with_additional_label
        @issues_with_additional_label ||=
            api_client.get("#{issue_query_prefix}labels=#{team.label},#{team.additional_label}&state=closed&milestone=#{release['title']}", auth: get_with_auth?)
    end

    def current_retrospective
        @current_retrospective ||= current_retrospective.first
    end

    def current_retrospectives
        if current_retrospectives_with_team_label.size > 0
            current_retrospectives_with_team_label
        else
            current_retrospectives_without_team_label
        end
    end

    def current_retrospectives_with_team_label
        @current_retrospectives_with_team_label ||= api_client.get(current_retrospectives_api_path([team.label]), auth: true)
    end

    def current_retrospectives_without_team_label
        @current_retrospectives_without_team_label ||= api_client.get(current_retrospectives_api_path, auth: true)
    end

    def issues
        @issues ||= api_client.get("#{issue_query_prefix}labels=#{team.label}&state=closed&milestone=#{release['title']}", auth: true)
    end

    def issue_count
        @issue_count ||= issues.size
    end

    def total_weight
        @total_weight ||= begin
            sum = issues.sum { |i| i['weight'] || 0 }

            return sum if issues.count == issues.headers['X-Total'].to_i

            "#{sum}+"
        end
    end

    def merge_request_count
        @merge_request_count ||=
            api_client.count("#{merge_request_query_prefix}labels=#{team.label}&state=merged&milestone=#{release['title']}")
    end

    def mention_team_owners
        owners = team.owner

        owners = [owners] unless owners.is_a?(Array)

        "@" + owners.join(' @')
    end

    private

    def template
        @template ||= load_template(team.template)
    end

    def load_template(filename)
        ERB.new(File.read("templates/#{filename}.erb"), trim_mode: '<>')
    end
end
