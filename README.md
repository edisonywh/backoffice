# Backoffice

![img](backoffice.png)

Backoffice is an admin tool built with the PETAL stack (**P**hoenix, **E**lixir, **T**ailwind, **A**lpine, **L**iveView).

## Why did you build Backoffice?

I was working on refactoring [Slick Inbox](https://slickinbox.com). I looked at my admin tool which is built with LiveView, and didn’t like the repetitions that I saw. I am repeating a lot of the same things (search, pagination, form components, index.html etc) on every admin page that I have. They’re pretty simple pages. So why not refactor that?

I looked at the repetitive stuffs, extracted them, and then suddenly it looks like it could be general enough to be a library, so I experimented more and thus born `Backoffice`! 🎉

Another reason is that I think it would be awesome to have more LiveView projects in the open where we can learn from each other!

## What about other alternatives?

I know of three alternatives thus far:

- [Ash Admin](https://github.com/ash-project/ash_admin)
- [Torch](https://github.com/mojotech/torch)
- [Kaffy](https://github.com/aesmail/kaffy)

Ash Admin seems to only support Ash resources, and I don't use that, so that doesn't work for me.

Torch is a generator, it hooks onto the Phoenix generator and then generate resources for you. I'm not sure if I like that idea (you don't get updates for free) but I think the filter feature is pretty neat.

Kaffy is probably the most matured out of the three, and so I'll mostly be comparing to it.

1. Kaffy uses controllers, Backoffice uses LiveView
2. Kaffy works by `using` it in your router, the available paths are hidden from you, and you supply the configurations via application env, whereas Backoffice prefers explicitness (per module) and less on application env.
3. Kaffy has a more seamless experience as it magics its way across your schemas, with Backoffice it requires a longer set-up as you need to create modules per page (but more explicit).
4. Kaffy works under the assumption of your application being database-backed - Backoffice has an interesting `Resolver` concept, so you can write your own resolver and fetch your data from anywhere.

For example, with Kaffy:

```elixir
# router.exs
defmodule YourApp.Router do
  use Kaffy.Routes
end
```

I’m not a fan of this idea since it’s not immediately obvious what routes are available. Kaffy routes are defined in `config.exs` (application env) which could potentially call out to a different `Config` module as well, but I prefer things to be colocated. To me, `router.exs` is the source of truth for the available routes in my app, so I prefer to keep everything centralised.

Therefore, with Backoffice:

```elixir
# router.exs

scope "/admin", YourAppWeb, do
  live("/users", UserLive.Index, :index) # these are your existing pages
  live("/users/:id/edit", UserLive.Index, :edit)

  live("/newsletters", Backoffice.NewsletterLive.Index, :index, layout: {Backoffice.LayoutView, :backoffice})
  live("/newsletters/:id/edit", Backoffice.NewsletterLive.Index, :edit, layout: {Backoffice.LayoutView, :backoffice})
end
```

It sits right next to your existing set-up! This was my main goal, to easily see what routes are available to me.

But, as you might have noticed, this means you need to create a lot more modules, compared to Kaffy.

> I should also add that I referred to Ash Admin's and Kaffy's codebase quite a bit, so huge thanks to the contributors!

## Usage

1. Create a Layout module

```elixir
# lib/slick_web/live/backoffice/layout.ex
# Icons are all from heroicons.com.
defmodule SlickWeb.Backoffice.Layout do
  @behaviour Backoffice.Layout

  def logo do
    SlickWeb.Router.Helpers.static_path(SlickWeb.Endpoint, "/images/admin-logo.svg")
  end

  def links do
    [
      %{
        label: "User",
        link: SlickWeb.Router.Helpers.user_index_path(SlickWeb.Endpoint, :index),
        icon: """
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        """
      },
      %{
        label: "LiveDashboard",
        link: "/admin/dashboard",
        icon: """
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
          </svg>
        """
      },
    ]
  end
end
```

2. Tell Backoffice about the layout you just created.

```elixir
# config.exs
config :backoffice, layout: SlickWeb.Backoffice.Layout
```

3. Create a resource module:

```elixir
# lib/slick_web/live/backoffice/user.ex
defmodule SlickWeb.Backoffice.UserLive.Index do
  use Backoffice.Resources,
    resolver:
      {Backoffice.Resolvers.Ecto,
       repo: Slick.Repo,
       changeset: %{edit: &Slick.Accounts.User.update_changeset/2},
       preload: [:mailbox, :notification_preference]},
    resource: Slick.Accounts.User

  def create, do: true
  def edit, do: true

  index do
    field :id
    field :verified, :boolean
    field :age, :string, render: &__MODULE__.field/1 # 1-arity only, takes the resource itself
  end

  form do # default for both
    field :verified, :boolean
    field :username, :string
    field :age, :custom, label: "Age", render: &__MODULE__.field/2 # 2-arity, `form` and `field`.
  end

  form :edit do # form for :edit action
    ...
  end

  form :new do # form for :new action
    ...
  end
end
```

4. Set-up your resource module in the route.

```elixir
scope "/admin", SlickWeb, do
  live("/users", Backoffice.UserLive.Index, :index, layout: {Backoffice.LayoutView, :backoffice})
  live("/users/:id/edit", Backoffice.UserLive.Index, :edit,
      layout: {Backoffice.LayoutView, :backoffice}
    )
end
```

5. You are done!

## Resolvers?

One interesting tidbit about Backoffice is that Backoffice itself doesn't make any assumption about where your data is from. This is pretty cool as it means Backoffice can ingest data from everywhere and display them!

The only requirement/caveat is:

- You need to build your own Resolver
- Your resource still needs to be a schema (embedded or not)

For example, you can write up an API resolver like this.

```elixir
defmodule Todo do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :userId, :string
    field :id, :string
    field :completed, :boolean
    field :title, :string
  end
end

defmodule Backoffice.Resolvers.API do
  @behaviour Backoffice.Resolver

  @impl true
  def load(Todo, resolver_opts, _page_opts) do
    url = Keyword.fetch!(resolver_opts, :url)

    resp = HTTPoison.get!(url)

    entries =
      resp.body |> Jason.decode!(keys: :atoms) |> Enum.take(20) |> Enum.map(&struct!(Todo, &1))

    # This is required for the pagination buttons to work
    %Backoffice.Page{
      entries: entries,
      page_number: 1,
      page_size: 10,
      total_entries: 100,
      total_pages: 5
    }
  end

  @impl true
  def search(mod, resource, resolver_opts, page_opts) do
    load(resource, resolver_opts, page_opts)
  end
end
```

## Can I use Backoffice in production?

You sure can, but I would not really advise it. Although it's in active development now, Backoffice is still very early stage (Backoffice isn't even on Hex yet), so it's subject to a lot of API changes.

For what it's worth, I am dogfodding it in production with [Slick Inbox](https://slickinbox.com).

There are quite a number of issues right now:

- [ ] Editing :map doesn't work
- [ ] Index & Form fields default might not be the best (form fields right now attempts to show assocs, but you need to explicitly preload it and you can't edit them yet.)
- [ ] Association support is not great
- [ ] Tailwind CSS is not being purged now, so the CSS file is about 3MB.
- [ ] etc...

But, I encourage you to try it out anyway and contribute, and together we can make Backoffice great :)

## What's next for Backoffice?

Honestly I'd really love for the community to contribute more, as I've mentioned before, Slick's admin tool usage is pretty basic, so I'm fairly certain there are a lot of use cases that Backoffice is not equipped to handle. I'd also love to learn more LiveView patterns and/or tips & tricks from the community.

Other than that, here are some things I hope to improve:

- [ ] Better support for associations?
- [ ] Custom color?
- [ ] Custom pages
- [ ] Datepicker support
- [ ] LiveComponent support (WIP. Required for complex form fields)
- [ ] Implement a test suite..
- [ ] Localization support?
- [ ] Authorisation?
- [ ] Widget support (probably in the form of LiveComponents)
- [ ] Better documentations

## Installation

Backoffice is not yet available on Hex, so to try it out you'd need to point to this Git repo.

```elixir
def deps do
  [
    {:backoffice, git: "https://github.com/edisonywh/backoffice"}
  ]
end
```
