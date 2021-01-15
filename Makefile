
setup:
	bundle config set path lib 
	bundle install

clean:
	( find . -name '*~' -type f -exec rm {} \; -print )
	rm -rf .bundle
	rm -rf lib/ruby
	rm -rf Gemfile.lock
