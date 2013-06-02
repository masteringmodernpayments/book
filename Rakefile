task :count do

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
        file_code_count += 1
      else
        file_word_count += line.split(/\w+/).compact.size
      end
    end

    code_count += file_code_count
    word_count += file_word_count

    puts "#{file}: #{file_word_count} #{file_code_count}"
  end

  puts "overall: #{word_count} #{code_count}"
end

task :check do
  count = 0
  Dir.glob('*.md').each do |file|
    next if file =~ /^_/

    matches = File.read(file).match(/(Essentially|Basically)/)
    if matches
      count += matches.count
      puts "#{file} matches"
    end
  end

  if count > 0
    exit 1
  end
  
end
