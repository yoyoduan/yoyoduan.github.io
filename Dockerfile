ARG VARIANT=3.3-bookworm
FROM mcr.microsoft.com/devcontainers/ruby:${VARIANT}

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        zlib1g-dev \
        nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Jekyll and Bundler
RUN gem install jekyll bundler

# Set workdir to app
WORKDIR /app

# Copy Gemfile
COPY Gemfile ./

# Install project dependencies
RUN bundle install

# Copy the rest of the project
COPY . .

# Expose default Jekyll port
EXPOSE 4000

# Default command to serve the site
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]