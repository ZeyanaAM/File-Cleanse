require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'csv'

$agent = Mechanize.new
$delay_time = 1

$agent = Mechanize.new
begin
issm = $agent.get('https://issm.berkeley.edu/')
loginform = issm.form
print "Enter issm username: "
issm_user = gets.chomp()
print "Enter issm password: "
issm_pwd = gets.chomp()
loginform.UserName = issm_user
loginform.Password = issm_pwd
page = $agent.submit(loginform)
rescue
end

$shortcut = $agent.get('https://issm.berkeley.edu/ListViewFrameset.asp?collegeId=3032095457&ID=84812')
$search = $shortcut.frames[1].click
$searchform = $search.form
$searchform.CampusId = ''


def find_student(last_name, first_name, dob)
  $searchform.LName = last_name
  $searchform.FName = first_name
  $searchform.DOB = dob

  student_page = $agent.submit($searchform, $searchform.buttons.first)
  return student_page
end

def find_compl_date(quickview, status)
  sleep($delay_time)
  interactions = quickview.link_with(:text => 'Interactions').click

  table = interactions.css('table')
  compl_date = ''

  if status == 'Complete'
    for i in 0...6 do
        id = 'tr#ctl07_ctl00__' + i.to_s
        break if table.css(id) == nil
        category = table.css(id).css('td')[4].text

        if category == 'AutoCompletion'
          compl_date = table.css(id).css('td')[1].text
        end
        break if compl_date != ""
    end
  end
  if compl_date == ""
      sleep($delay_time)
      sevis = interactions.link_with(:text => 'SEVIS').click
      table = sevis.css('table')
      j = 2
      if status == 'Complete'
        term = "Student Completion"
      elsif status == 'Terminated'
        term = "Student Termination"
      end
      until table.css('a#SEVISArchivedEvents_ctl0' + j.to_s + '_ArchivedEventsName').text == ""
          event_line = table.css('a#SEVISArchivedEvents_ctl0' + j.to_s + '_ArchivedEventsName').text
          event = event_line.split[2].to_s + " " + event_line.split[3].to_s
          if event == term
            timestamp = table.css('span#SEVISArchivedEvents_ctl0' + j.to_s + '_ArchivedTimeStamp').text
            compl_date = timestamp.split[7]
          end
          j += 1
      end
  end
  if compl_date == ""
      sleep($delay_time)
      suppressed = sevis.link_with(:text => "View Suppressed Event(s)").click
      puts "Entered Suppressed"
      num = 3
      for num in 3...13 do
        id = 'SuppressedSevents_ctl0' + num.to_s + '_SeventNames'
        puts id
        supevent = suppressed.css('td.SeventGradientBg').css('a#' + id).text
        puts supevent
        puts supevent[-18..-1]
        if supevent[-18..-1] == 'Student Completion'
          index = num - 3
          compl_date = suppressed.css('tr.SeventItem')[index].text.split[-3]
          puts index
          puts compl_date
        end
      end
  end
  return compl_date
end


def getinfo(last_name, first_name, dob)

  sid = ''
  status = ''
  compl_date = ''
  file_name = ''
  student_type = ''

  student_page = find_student(last_name, first_name, dob)
  if student_page.css('span#RecordCountLBL').text == '0'
    if last_name[-1] != " " and first_name[-1] != " "
      file_name = last_name + "," + first_name
    end
    student_page = find_student(last_name[0..1], first_name[0..1], dob)
  end
  if student_page.css('span#RecordCountLBL').text == '1'
    search_name = student_page.css('a#ResultGrid_ctl02_NameHLINK').text
    quickview = student_page.link_with(:text => search_name).click
    sid = quickview.css('span#BasicDataTable_CampusId').text
    status = quickview.css('span#BasicDataTable_ProfileStatus').text
    student_type = quickview.css('span#BasicDataTable_ProfileType').text
    if status == 'Complete' or status == 'Terminated'
      compl_date = find_compl_date(quickview, status)
    end
  end
  return sid, status, file_name, compl_date, student_type
end


def process_csv(input_file, output_file)
  CSV.foreach(input_file) do |row|
    if row[0] != ''
      #ignore first two rows
      last_name = row[0]
      if last_name == nil
        last_name = ""
      end
      first_name = row[1]
      if first_name == nil
        first_name = ""
      end
      dob = row[2]
      if dob == nil
        dob = ""
      end
      puts last_name
      puts first_name
      puts dob


      sid, status, file_name, compl_date, student_type = getinfo(last_name, first_name, dob)
      puts sid
      puts status
      puts compl_date
      puts student_type

      row[3] = sid
      if status == 'SEVIS - Active'
        status = 'Active'
      end
      row[4] = status
      row[5] = file_name
      row[6] = compl_date

      #case where finds no result, put in physical file
      if sid == ''
        row[5] = last_name + ',' + first_name
      end

      if student_type == 'H-1'
        row[7] = student_type
      end

    end
    sleep($delay_time)
    puts row.inspect
    CSV.open(output_file, "a") do |csv|
      csv << row
    end
  end

end

input_file = "/Users/Phoenix/Documents/Go Bears!/Coding/File Cleanse BIO/File Cleanse Input/extra.csv"
output_file = "/Users/Phoenix/Documents/Go Bears!/Coding/File Cleanse BIO/File Cleanse Output/extra_cleansed.csv"
process_csv(input_file, output_file)
