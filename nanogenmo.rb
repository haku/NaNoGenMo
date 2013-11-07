#!/usr/bin/env ruby
# encoding: UTF-8

# Generates random fiction by harvesting stories from Fanfiction.net and randomly
# combining the sentences it finds.

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'yaml'

######### CONFIGURATION ##########

# Pick a Fanfiction.net page that has links to stories. This can be a category, user or
# search page, e.g.
# http://www.fanfiction.net/tv/Doctor-Who/
# http://www.fanfiction.net/search.php?keywords=cupcakes&ready=1&type=story
# http://www.fanfiction.net/u/1234567/UserName
INDEX_URL = 'http://www.fanfiction.net/tv/Doctor-Who/'

# Fetch live data from the web. "true" is the normal use case. If you have previously run
# the script and want to run it again to get a new story with the same data set (i.e.
# without spending ages scraping data from the web again) you can set this to "false".
FETCH_LIVE_DATA = true

## Less common config options
# Fanfiction.net base URL for following relative links
BASE_URL = 'http://www.fanfiction.net'
# Fake a user agent to avoid getting 403 errors
USER_AGENT = 'Mozilla/5.0 (X11; Ubuntu; Linux armv7l; rv:24.0) Gecko/20100101 Firefox/24.0'
# Intermediate and output file names to use
DATA_CACHE_FILE_NAME = 'cache.yaml'
STORY_MARKDOWN_FILE_NAME = 'story.md'
STORY_HTML_FILE_NAME = 'story.html'
# Tags, IDs, classes and regexes to find and extract stories, pages, and sentences.
STORY_LINK_CLASS = 'stitle'
CHAPTER_SELECT_ID = 'chap_select'
SENTENCE_REGEX = /[^.!?\s][^.!?]*(?:[.!?](?!['"]?\s|$)[^.!?]*)*[.!?]?['"]?(?=\s|$)/
# Tweaks
WORD_GOAL = 1000
SOLITARY_RATE = 0.1 # For every 1 proper paragraph, there will be this many solitary (one-sentence) paragraphs.
DIALOGUE_RATE = 0.2 # For every 1 proper paragraph, there will be this many dialogue sequences.
MAX_SENT_PER_PARA = 6 # Maximum number of sentences per paragraph
MAX_SENT_PER_DIALOGUE = 6 # Maximum number of sentences / lines in a dialogue section.

######### CODE STARTS HERE ##########

# If we're fetching live data, as opposed to reading an existing file...
if FETCH_LIVE_DATA
	# First fetch the HTML for the chosen index page, and find all the links to stories.
	print 'Finding stories...'
	indexHTML = Nokogiri::HTML(open(INDEX_URL, 'User-Agent' => USER_AGENT))
	storyLinkTags = indexHTML.css("a.#{STORY_LINK_CLASS}")
	storyURLs = []
	storyLinkTags.each do |tag|
		storyURLs << BASE_URL + tag['href']
	end
	print " #{storyURLs.size} found.\n"

	# Now you have a link to the "Chapter 1" page of each story. For each "Chapter 1" page,
	# look for a SELECT box that will provide links to any other chapters. Add them all to
	# a new array of pages.
	print 'Finding pages...'
	pageURLs = []
	storyURLs.each do |chapterOneURL|
		# The URL we already have is a valid page, so add that first
		pageURLs << chapterOneURL
		
		# Now go looking for others
		chapterOneHTML = Nokogiri::HTML(open(chapterOneURL, 'User-Agent' => USER_AGENT))
		optionElements = chapterOneHTML.css("select\##{CHAPTER_SELECT_ID} option")
		optionElements.each do |option|
		  # Figure out what the URL for that page would be
		  chapterURL = chapterOneURL.sub(/\/1\//, "\/#{option['value']}\/")
		  # Add to the page URLs list if it's not already in there
		  if !pageURLs.include?(chapterURL)
		    print '.'
		  	pageURLs << chapterURL
		  end
		end
	end
	print " #{pageURLs.size} found.\n"

	# Create a data structure that will hold each sentence in an array, sorted by which
	# type of sentence it is.
	sentences = {
		:startChapters => [],
		:endChapters => [],
		:startParagraphs => [],
		:midParagraphs => [],
		:endParagraphs => [],
		:solitary => [],
		:dialogue => []
	}
	
	# For each page URL, load the page and extract sentences.
	print 'Extracting sentences'
  pageURLs.each do |pageURL|
    print '.'
  	pageHTML = Nokogiri::HTML(open(pageURL, 'User-Agent' => USER_AGENT))
		paragraphs = pageHTML.css("p")
		paragraphs.each_with_index do |para, pi|
		  # Take the contents of each <p> element, remove linebreaks and scan for sentences
			tmpSentences = para.text.tr("\n"," ").tr("\r"," ").scan(SENTENCE_REGEX)
			tmpSentences.each_with_index do |tmpSentence, i|
			print "#{tmpSentence}\n--\n"
			  if (pi == 0) && (i == 0)
			    sentences[:startChapters] << tmpSentence
			  elsif (pi == paragraphs.size - 1) && (i == tmpSentences.size - 1)
			    sentences[:endChapters] << tmpSentence
			  elsif tmpSentence.include? '"'
			    sentences[:dialogue] << tmpSentence
			  elsif tmpSentences.size == 1
			     sentences[:solitary] << tmpSentence
			  elsif i == 0
			     sentences[:startParagraphs] << tmpSentence
			  elsif i == tmpSentences.size - 1
			     sentences[:endParagraphs] << tmpSentence
			  else
			     sentences[:midParagraphs] << tmpSentence
			  end
			end
		end
  end
  print " #{sentences[:startChapters].size + sentences[:endChapters].size + sentences[:startParagraphs].size + sentences[:midParagraphs].size + sentences[:endParagraphs].size + sentences[:solitary].size + sentences[:dialogue].size} found.\n"
	
	# Serialise the data to disk for later use
	print "Saving data to #{DATA_CACHE_FILE_NAME}..."
	serialisedSentences = YAML::dump(sentences)
	File.open(DATA_CACHE_FILE_NAME, 'w') { |file| file.write(serialisedSentences) }
	print " Done.\n"

else
	# We're not fetching live data, so load it from a file saved previously
	
	if File.file?(DATA_CACHE_FILE_NAME)
		print "Loading data from #{DATA_CACHE_FILE_NAME}..."
		serialisedSentences = File.read(DATA_CACHE_FILE_NAME)
		sentences = YAML::load(serialisedSentences)
		print " #{sentences[:startChapters].size + sentences[:endChapters].size + sentences[:startParagraphs].size + sentences[:midParagraphs].size + sentences[:endParagraphs].size + sentences[:solitary].size + sentences[:dialogue].size} sentences loaded.\n"
	else
	  # No file, so error out
		print "FETCH_LIVE_DATA was set to 'false' but a data file named #{DATA_CACHE_FILE_NAME} could not be found. This means there is no source of data for the script to use. Check your configuration.\n"
		exit
	end

end


# Start generating. If we get here, we know that sentences has contents that we can use.
story = ''
print 'Generating story'

# Start with an opening sentence
story << sentences[:startChapters][rand(sentences[:startChapters].size - 1)] << "\n\n"

# Keep going until word count goal is reached
while story.split.size < WORD_GOAL
  print '.'
  # Decide what type of section we are going into - a proper paragraph (at least 2 
  # sentences), a solitary sentence, or a dialogue section.
  roll = rand * (1 + SOLITARY_RATE + DIALOGUE_RATE)
  if roll < SOLITARY_RATE
    # Solitary. Pick a solitary paragraph and concatenate it to the story.
    story << sentences[:solitary][rand(sentences[:solitary].size - 1)] << "\n\n"
  elsif roll < (SOLITARY_RATE + DIALOGUE_RATE)
    # Dialogue. First work out how long the dialogue should be.
    dialogueLength = rand(MAX_SENT_PER_DIALOGUE)
    # Now add that many dialogue paragraphs.
    for i in 0..dialogueLength
      story << sentences[:dialogue][rand(sentences[:dialogue].size - 1)] << "\n\n"
    end
  else
    # Normal Paragraph. First work out how long the paragraph should be. Must be at
    # least 2
    paragraphLength = rand(MAX_SENT_PER_PARA - 1) + 1
    # Now add a beginning sentence, the right number of middle sentences, and an end
    # sentence.
    story << sentences[:startParagraphs][rand(sentences[:startParagraphs].size - 1)] << ' '
    for i in 0..paragraphLength-2
      story << sentences[:midParagraphs][rand(sentences[:midParagraphs].size - 1)] << ' '
    end
    story << sentences[:endParagraphs][rand(sentences[:endParagraphs].size - 1)] << "\n\n"
  end
end

# Finish with a closing sentence
story << sentences[:endChapters][rand(sentences[:endChapters].size - 1)] << "\n\n"

print " wrote #{story.split.size} words!\n"

# Save the file as markdown
print 'Saving file...'
File.open(STORY_MARKDOWN_FILE_NAME, 'w') {|f| f.write(story) }
print " done.\n"

print "\n\n\n"
print story