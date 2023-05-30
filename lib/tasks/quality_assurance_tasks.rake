desc "Some quality assureance tasks"
task :quality_assurance_tasks => :environment do
  admin = User.find_by(id: 1)
  # Close long inactive
  # issues = Issue.includes(:project).where("issues.updated_on < '#{12.months.ago}' AND status_id = 1").where(projects: {status: 1}).where("projects.updated_on > '#{2.years.ago}'")
  # issues.each do |issue|
  #   issue.init_journal(admin, "Automatically closed by admin because it has been inactivated for an year")
  #   issue.closed_on = Time.now
  #   issue.updated_on = Time.now
  #   issue.status_id = 5
  #   issue.save
  # end
  
  # Auto create version & set default for active project
  project = Project.find_by(identifier: "ventura")
  version = project.versions.build
  version.name = Date.today.strftime("%Y-%m")
  version.description = Date.today.strftime("%Y-%m")
  version.effective_date = Date.today.end_of_month
  version.sharing = "system"

  if version.save
    Project.where(status: 1).where.not(default_version_id: nil).update_all(default_version_id: version.id)
  end

  ## Close old tasks: 1
  subtasks = Rails.cache.read('support-task')
  subtasks.each do |subtask|
    issue = Issue.find_by_id(subtask)
    next if issue.nil?
    issue.init_journal(admin)
    issue.status_id = 5
    issue.save
  end

  # Auto create 5 support tasks every month
  # APW: 133, Sumai Maintain: 131, Sumai App Renewal: 140, Kyujin: 9, LS: 134, Minden: 112, UsedCar: 90, PS: 141, knoock: 142, Voyager: 146
  # @TODO: should get them from a setting
  project_ids = [133, 131, 140, 9, 134, 112, 90, 141, 142, 146]
  subtasks2 = []
  subtask_titles = %w(Leave\ off Communication\ -\ Meeting\ Monthly/daily Idle Management\ Cost Support\ JP)
  project_ids.each do |project_id|
      subtask_titles.each do |subtask_title|
          subtask = Issue.new
          subtask.subject = subtask_title + ' - ' + Date.today.strftime("%B %Y")
          subtask.tracker_id = 3 #Support
          subtask.estimated_hours = nil
          subtask.fixed_version_id = version.id
          subtask.project_id = project_id
          subtask.author = admin
          subtask.start_date = Date.today.beginning_of_month
          subtask.due_date = Date.today.end_of_month
          subtask.save!
          subtasks2 << subtask.id
      end
  end
  Rails.cache.write('support-task', subtasks2)
  p 'Done!'

end
