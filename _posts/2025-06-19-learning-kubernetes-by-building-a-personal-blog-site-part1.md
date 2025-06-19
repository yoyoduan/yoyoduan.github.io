---
title: Learning Kubernetes by Building a Personal Blog Site — Part 1: Set Up a Blog Site Locally
date: 2025-06-19 19:19:00 +0800
description: The blog is walk through how to set up a blog site locally.
categories: [Kubernetes, Docker]
tags: [kubernetes, docker, jekyll, web-application]
media_subpath: /assets/img/blog-site/
---


Welcome to the first post in our "Learning Kubernetes by Building a Personal Blog Site" series! In this post, we’ll walk through how to set up a blog site locally — the blog site is just like the one you’re reading now!

By the end of this post, you’ll be able to:
1. Set up your own blog site locally using the same theme as this blog.
2. Deploy your blog to GitHub Pages so that others can access it at a URL like `https://<your-github-username>.github.io/`. For example, mine is [https://yoyoduan.github.io](https://yoyoduan.github.io).

> 📌 Tip: If you’re here mainly for Kubernetes, you can skip the deployment to GitHub Pages section below. This post also works as a standalone tutorial on setting up a personal blog.

Our blog uses [Jekyll](https://jekyllrb.com/), a static site generator written in Ruby. But don’t worry — you **don’t** need to know Ruby, and you don’t need to be a frontend expert to follow along. I’m not either. If you’ve got some basic programming experience and can use Git and a terminal, you’re good to go.

### What you’ll need:

* You’re comfortable writing in Markdown.
* You have some programming experience (frontend, backend, or DevOps — any is fine).
* You know how to use Git and GitHub.
* You know basic Linux terminal commands.

---

## Set Up Your Blog Site Locally

This blog uses the [Chirpy Jekyll theme](https://github.com/cotes2020/jekyll-theme-chirpy/). Most of the setup steps follow its official [Getting Started](https://chirpy.cotes.page/posts/getting-started/) guide — with beginner-friendly explanations added.

Think of any application setup as needing three parts:
1. A **runtime environment**
2. The **actual project source code**
3. The **dependencies** of project needs to run

Let’s walk through each step.

---

### Step 1: Install the Runtime Environment (Linux Only)

I’m using Ubuntu, so I’ll show the setup steps for Linux. If you're using Windows or macOS, check [Jekyll's installation guide](https://jekyllrb.com/docs/installation/).

Open your terminal and run:
```bash
sudo apt-get install ruby-full build-essential zlib1g-dev
sudo apt install -y nodejs
```

This installs:
* **Ruby** – Jekyll is a Ruby program, so this is essential. This comes from the `ruby-full`.
* **Gem** – The Ruby package manager, used to install Ruby packages called **gems**. It’s included in `ruby-full` as well.
* **Node.js** – Required by the Jekyll Chirpy theme to support features like search and dark mode. This comes from the `nodejs`.
* **Other prerequisite build tools**: `build-essential` and `zlib1g-dev`. These are needed to compile certain Ruby gems. Honestly, I don’t fully understand what they do either — and that’s okay. You can still follow this guide without knowing the details.

Now, install the required gems — Jekyll and Bundler:

```bash
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

gem install jekyll bundler
```

> 📝 **What do the first four commands do?**
>
> These lines:
>
> * Set an environment variable `GEM_HOME`. This tells Ruby to install gems into `~/gems`, a folder in your home directory where you always have write access.
> * Add `$HOME/gems/bin` to your system `PATH`, so you can run installed gems like `jekyll` or `bundler` directly from the command line — without needing to specify their full path (e.g., from `~/gems/bin/bundler` to simply `bundler`).
> * Save these settings in your `.bashrc` file so they persist across terminal sessions.

> 💡 **Why not just use `sudo gem install`?**
>
> By default, Ruby tries to install gems system-wide, which often requires `sudo` and can cause permission issues or conflicts with system-level packages. It’s safer to install them locally in your home directory (`~/gems`), where you always have write access.

> 🔧 **What’s Bundler?**
>
> Bundler manages Ruby dependencies. It makes sure you have the right versions of gems installed, helping avoid compatibility issues during builds.

---

### Step 2: Get Your Blog Project Source Code from GitHub
1. Fork the [chirpy-starter](https://github.com/cotes2020/chirpy-starter) repository to your own GitHub account. This is the template we'll use to build your blog.
2. Name the forked repository `<your-username>.github.io`.
   This is required if you want to host it using GitHub Pages. After deployment, your blog site will be publicly accessible at `https://<your-username>.github.io`.
3. Clone the repo to your local computer:
   ```bash
   cd <your-project-folder>
   git clone https://github.com/<your-username>/<your-username>.github.io.git
   ```

   Example:

   ```bash
   git clone https://github.com/yoyoduan/yoyoduan.github.io.git
   ```

---

### Step 3: Install Project Dependencies
The Chirpy theme requires some additional gems to work properly. These are listed in a file named `Gemfile` in the root of your project repository — think of it as a "shopping list" of required gems.

To install them, navigate to your project folder and run:
```bash
bundle
```

This command will:
* Install all the gems listed in the `Gemfile`
* Automatically install any sub-dependencies those gems require

---

## Run Your Blog Locally
Everything is ready now — let’s start the blog server and see it in action! In your terminal, run:
```bash
bundle exec jekyll serve
```

After a few seconds, you’ll see your blog running at [http://127.0.0.1:4000](http://127.0.0.1:4000):

![screenshot-local-blog-site](screenshot-local-blog-site.png)

---

### Add Your First Blog Post

Want to write your first post? Just create a new `.md` file (a Markdown file) under the `_posts/` directory. Here’s a simple example:

```markdown
---
title: My First Blog
date: 2025-06-17 10:38:00 +0800
description: A sample blog
categories: [Blog]
tags: [jekyll]
---

## Introduction
My first blog!
```

> The block at the top (`---`) is called **front matter**. It tells Jekyll about the post’s metadata, like the title and date. It won’t appear on the page, but Jekyll needs it to build the post properly.

Now refresh your browser — you should see the new post on the homepage. Click it to read your content!

![First blog on the homepage](first-blog-on-the-home-page.png)
![First blog content](first-blog.png)

---

## (Optional) Deploy to GitHub Pages
Seeing your blog locally is fun — but what if you want to share it with the world?

GitHub Pages lets you host static websites for **free**! Just push your latest change to GitHub, and your blog will be live at `https://<your-username>.github.io`. Make sure your repository name is **exactly** `<your-username>.github.io`.

```bash
git add .
git commit -m "Add my first blog"
git push origin main
```

Then:

1. Go to your repo on GitHub → **Settings**
2. Click **Pages** in the sidebar
3. Under "GitHub Pages", click **Visit site**

> ⏳ It might take a few minutes before your blog appears. Be patient!

![GitHub Pages Settings](github-pages.png)
![Visit site](github-pages2.png)
![Live blog](github-pages3.png)

---

## Next Steps

Now that your blog is up and running, you're ready for the next phase — **containerizing** it with Docker.

Not sure what "containerizing" means? I’ll explain it in detail in the next post. But here's a quick preview: it's a way to "package" your blog site into a single, portable unit that can be deployed anywhere. This will help us run the blog not only on your local machine, but also inside a Kubernetes cluster.

Ready to continue? Let’s go to [Part 2: Using Docker to Simplify Setup](#To-do) →
