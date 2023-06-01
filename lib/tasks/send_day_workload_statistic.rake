desc "Send day workload statistic"
task :send_day_workload_statistic => :environment do

  include StatisticHelper
  include SlackNotificatorHelper

  day_statistic_enable  = Setting.plugin_workload_statistic_notificator['day_statistic_enable']

  if day_statistic_enable
    time_now           = Time.now.strftime("%H:%M")
    day_statistic_time = Setting.plugin_workload_statistic_notificator['day_statistic_time']

    p time_now

    if time_now == day_statistic_time
      url     = Setting.plugin_workload_statistic_notificator['slack_url']
      channel = Setting.plugin_workload_statistic_notificator['day_statistic_channel']
      icon    = Setting.plugin_workload_statistic_notificator['icon']

      color_top    = '#2FA44F'
      color_bottom = '#F35A00'
      color_idle   = '#E2E3E5'

      statistic = StatisticHelper::get_day_statistic
      return if statistic.empty?

      statistic.each do |name, team|
        next if team[:url].empty? || team[:channel].empty?
        attachment = []
        message = "*Daily Report - #{name} - #{ DateTime.now.strftime("%d-%b-%Y")}*"
        if team[:time_top].empty? && team[:time_bottom].empty? && team[:time_idle].empty?
          attachment = [
            {
              :text => "it seems like no users are selected for the report or non of them are assigned to internal projects",
            }
          ]
        else
          team[:time_top].each do |item|
            attachment.push({
                                :text      => "#{item[0]} `#{item[1]}h` #{item[2]}",
                                :mrkdwn_in => ["text"],
                                :color     => color_top
                            })
          end

          team[:time_bottom].each do |item|
            attachment.push({
                                :text      => "#{item[0]} `#{item[1]}h` #{item[2]}",
                                :mrkdwn_in => ["text"],
                                :color     => color_bottom
                            })
          end

          team[:time_idle].each do |item|
            attachment.push({
                                :text      => "#{item[0]}",
                                :mrkdwn_in => ["text"],
                                :color     => color_idle
                            })
          end
        end
        SlackNotificatorHelper::send_notification team[:url], team[:channel], icon, message, attachment
      end
    end
  else
    p 'Day statistic is disabled in plugin configuration'
  end

end
