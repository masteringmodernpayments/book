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

    puts "#{file}\t\t#{file_word_count}\t#{file_code_count}"
  end

  puts "overall\t\t#{word_count}\t#{code_count}"
end
