## Install the jekyll environment locally:

ttps://jekyllrb.com/docs/installation/ubuntu/

sudo apt-get install ruby-full build-essential zlib1g-dev

echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

gem install jekyll bundler

# Download node.js
sudo apt install -y nodejs

yoyo@yoyovm:~/yoyoduan.github.io$ bundle
Fetching gem metadata from https://rubygems.org/...........
Resolving dependencies...
Fetching rake 13.3.0
Installing rake 13.3.0
Fetching Ascii85 2.0.1
Fetching afm 0.2.2
Installing Ascii85 2.0.1
Fetching fiber-annotation 0.2.0
Installing afm 0.2.2
Fetching fiber-storage 1.0.1
Installing fiber-annotation 0.2.0
Fetching json 2.12.2
Installing fiber-storage 1.0.1
Fetching io-event 1.11.0
Installing json 2.12.2 with native extensions
Installing io-event 1.11.0 with native extensions
Fetching metrics 0.12.2
Installing metrics 0.12.2
Fetching traces 0.15.2
Installing traces 0.15.2
Fetching bigdecimal 3.2.2
Installing bigdecimal 3.2.2 with native extensions
Fetching csv 3.3.5
Installing csv 3.3.5
Fetching hashery 2.1.2
Installing hashery 2.1.2
Fetching racc 1.8.1
Installing racc 1.8.1 with native extensions
Fetching ruby-rc4 0.1.5
Installing ruby-rc4 0.1.5
Fetching rainbow 3.1.1
Installing rainbow 3.1.1
Fetching yell 2.2.2
Installing yell 2.2.2
Fetching zeitwerk 2.7.3
Installing zeitwerk 2.7.3
Fetching webrick 1.9.1
Installing webrick 1.9.1
Fetching jekyll-paginate 1.1.0
Installing jekyll-paginate 1.1.0
Fetching fiber-local 1.1.0
Installing fiber-local 1.1.0
Fetching ethon 0.16.0
Installing ethon 0.16.0
Fetching nokogiri 1.18.8 (x86_64-linux-gnu)
Installing nokogiri 1.18.8 (x86_64-linux-gnu)
Fetching console 1.31.0
Installing console 1.31.0
Fetching typhoeus 1.4.1
Installing typhoeus 1.4.1
Fetching async 2.24.0
Installing async 2.24.0
Fetching ttfunk 1.8.0
Fetching jekyll-archives 2.3.0
Installing ttfunk 1.8.0
Installing jekyll-archives 2.3.0
Fetching jekyll-include-cache 0.2.1
Fetching jekyll-seo-tag 2.8.0
Installing jekyll-include-cache 0.2.1
Fetching jekyll-sitemap 1.4.0
Installing jekyll-seo-tag 2.8.0
Fetching pdf-reader 2.14.1
Installing jekyll-sitemap 1.4.0
Fetching jekyll-theme-chirpy 7.3.0
Installing pdf-reader 2.14.1
Installing jekyll-theme-chirpy 7.3.0
Fetching html-proofer 5.0.10
Installing html-proofer 5.0.10
Bundle complete! 5 Gemfile dependencies, 63 gems now installed.
Use `bundle info [gemname]` to see where a bundled gem is installed.
1 installed gem you directly depend on is looking for funding.
  Run `bundle fund` for details

Why are extra gems installed?
- Direct dependencies: The gems you list in your Gemfile.
- Transitive dependencies: Gems required by your direct dependencies.
For example, jekyll-theme-chirpy depends on Jekyll, and Jekyll in turn depends on many other gems (like async, addressable, etc.). Bundler resolves and installs all these dependencies to ensure your project works.

Summary
- You define a few gems in your Gemfile.
- Bundler installs those plus all gems they depend on.
- That’s why you see many more gems installed than you listed.

## Build the docker image:
> docker build -t my-jekyll-blog .

> docker run -p 4000:4000 my-jekyll-blog

> # Visit http://localhost:4000 in your browser.