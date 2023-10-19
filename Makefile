
.PHONY: setup
setup:
	bundle config set path lib 
	bundle install

.PHONY: clean
clean:
	( find . -name '*~' -type f -exec rm {} \; -print )
	rm -rf .bundle
	rm -rf lib/ruby
	rm -rf Gemfile.lock

.PHONY: config-uoacrawler
config-uoacrawler:
	./setup-rabbitmq-queues.rb setup config-uoacrawler.json
