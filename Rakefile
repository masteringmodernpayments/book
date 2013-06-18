task :default => [:count, :check_tics, :check_todos]

task :count do

  goal_count = 30000.0

  code_count = 0
  word_count = 0
  
  Dir.glob('*.md').each do |file|
    next if file =~ /^_/

    file_code_count = 0
    file_word_count = 0

    in_code_block = false
    File.open(file).each do |line|
      if line =~ /^```/
        in_code_block = !in_code_block
        next
      end

      if in_code_block
        file_code_count += 1 unless line =~ /^\s+$/
      else
        file_word_count += line.split(/\s+/).compact.size
      end
    end

    code_count += file_code_count
    word_count += file_word_count

    puts "#{file}: #{file_word_count} #{file_code_count}"
  end

  goal_pct = (word_count / goal_count * 100).round
  puts "overall: #{word_count} #{code_count} (#{goal_pct}%)"
end

task :check_tics do
  count = 0
  Dir.glob('*.md').each do |file|
    next if file =~ /^_/

    matches = File.read(file).match(/(Essentially|Basically)/)
    if matches
      count += matches.length
      puts "#{file} matches"
    end
  end

  if count > 0
    exit 1
  end
end

task :check_todos do
  count = 0
  Dir.glob('*.md').each do |file|
    next if file =~ /^_/

    File.open(file).each_with_index do |line, line_num|
      if line =~ /TODO/
        puts "#{file}:#{line_num+1} #{line.rstrip()}"
        count += 1
      end
    end
  end

  if count > 0
    exit 1
  end
end

task :pdf do
  system("curl -u admin:bugsplat1234 http://guide.subspace.bugsplat.info/_book.pdf > out.pdf")
end

