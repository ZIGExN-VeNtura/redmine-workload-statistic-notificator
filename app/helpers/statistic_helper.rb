module StatisticHelper

  include NotificatorSettingsHelper

  def get_day_statistic
    user_notification_settings = get_user_notification_settings
    internal_project_attr      = Setting.plugin_workload_statistic_notificator['is_internal_project_attr']
    daily_working_hours        = Setting.plugin_workload_statistic_notificator['daily_working_hours'].to_f

    users_time = user_notification_settings[:user_time]

    time_top    = []
    time_bottom = []
    time_idle   = []

    unless user_notification_settings[:enabled_users].empty?

      str_arr    = user_notification_settings[:enabled_users].to_s

      str_arr['['] = '('
      str_arr[']'] = ')'

      time_statistic = ActiveRecord::Base.connection.execute("
      SELECT
        users.id                   AS user_id,
        users.login                AS user_name,
        users.firstname            AS firstname,
        users.lastname             AS lastname,
        time_entries.activity,
        time_entries.project,
        time_entries.subject,
        time_entries.due_date,
        time_entries.done_ratio,
        spent_on,
        hours
      FROM users
        LEFT JOIN ( SELECT user_id, enumerations.name as activity,
          projects.name as project,
          issues.subject,
          issues.due_date,
          issues.done_ratio,
          spent_on,
          hours
          FROM time_entries
          LEFT JOIN `projects` ON `projects`.`id` = `time_entries`.`project_id`
          LEFT OUTER JOIN `enumerations` ON `enumerations`.`id` = `time_entries`.`activity_id` AND `enumerations`.`type` IN ('TimeEntryActivity') 
          LEFT OUTER JOIN issues ON issues.id = time_entries.issue_id
          WHERE spent_on = CURDATE()
          ) as time_entries
        ON users.id = time_entries.user_id
      WHERE users.id IN  #{str_arr}
      ORDER BY users.id
    ").to_a
      projects = ActiveRecord::Base.connection.execute("
        SELECT projects.name as project, custom_fields.name, value, group_concat(members.user_id) as members 
        FROM `custom_values` 
        LEFT OUTER JOIN `custom_fields` ON `custom_fields`.`id` = `custom_values`.`custom_field_id`
        LEFT OUTER JOIN `members` ON `members`.`project_id` = `custom_values`.`customized_id`
        LEFT JOIN `projects` ON `projects`.`id` = customized_id
        WHERE `custom_values`.`customized_type` = 'Project' AND value is not null AND value != ''
          AND custom_fields.name in ('Daily Slack URL', 'Daily Slack Channel') AND projects.status = 1
        GROUP BY customized_id, custom_fields.name
      ").to_a.group_by(&:shift)

      result = {}
      time_statistic.group_by(&:shift).each do |user_id, user|
        sum_spend_hours = 0
        issue = ''
        user_name = ''

        user.each do |item|
          spend_hours = item[9]
          user_name = "#{item[1]} #{item[2]}"

          if !spend_hours.nil?
            sum_spend_hours += spend_hours
            issue += "\n * #{item[3]} - #{item[4]} - #{item[5]} - #{item[6]} - #{item[7]}%"
          else
            record = ["#{item[1]} #{item[2]}", nil]
            projects.each do |project_name, project|
              result[project_name] = {:time_top => [], :time_bottom => [], :time_idle => [], :url => '', :channel => ''} if result[project_name].nil?
              if !project[0].nil? && project[0][2].split(",").include?(user_id.to_s)
                result[project_name][:time_idle].push(record)
                result[project_name][:url] = project[1][1]
                result[project_name][:channel] = project[0][1]
              end
            end
          end
        end

        unless sum_spend_hours.zero?
          required_time = daily_working_hours
          percentage    = ((sum_spend_hours.to_f / required_time) - 1) * 100
          record        = ["#{user_name}", sum_spend_hours, "#{issue}"]
          projects.each do |project_name, project|
            result[project_name] = {:time_top => [], :time_bottom => [], :time_idle => [], :url => '', :channel => ''} if result[project_name].nil?
            if !project[0].nil? && project[0][2].split(",").include?(user_id.to_s)
              if percentage >= 0
                result[project_name][:time_top].push(record)
              else
                result[project_name][:time_bottom].push(record)
              end

              result[project_name][:url] = project[1][1]
              result[project_name][:channel] = project[0][1]
            end
          end
        end
      end
    end

    # {:project_name => {:time_top => time_top, :time_bottom => time_bottom, :time_idle => time_idle, :url => url, :channel => channel}}
    result
  end

end
