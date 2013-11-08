# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = 'NaNoGenMo'
  s.version     = '1'
  s.date        = '2013-11-08'
  s.summary     = 'National Novel Generation Month.'
  s.description = 'A script to automatically generate a 50,000-word "novel" during November, as an alternative to writing it.'
  s.homepage    = 'https://github.com/ianrenton/NaNoGenMo'
  s.authors     = ['Ian Renton', 'haku']

  s.files       = ['lib/fanfiction_client.rb',
                   'lib/sentence_indexer.rb',
                   'lib/story_generator.rb']
  s.test_files  = []
  s.require_paths = ["lib"]

  s.add_dependency 'nokogiri'
  s.add_dependency 'redcarpet'
  s.add_dependency 'sqlite3'
end
