defmodule BettingWeb.CoreComponents do
  @moduledoc """
  Shared UI components — shadcn/ui-style building blocks.
  """
  use Phoenix.Component

  attr :flash, :map
  attr :kind, :atom

  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 space-y-2">
      <%= if msg = Phoenix.Flash.get(@flash, :info) do %>
        <div class="rounded-lg bg-primary px-4 py-3 text-sm text-primary-foreground shadow">
          <%= msg %>
        </div>
      <% end %>
      <%= if msg = Phoenix.Flash.get(@flash, :error) do %>
        <div class="rounded-lg bg-destructive px-4 py-3 text-sm text-white shadow">
          <%= msg %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={"bg-card text-card-foreground flex flex-col gap-6 rounded-xl border py-6 shadow-sm #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_header(assigns) do
    ~H"""
    <div class={"px-6 #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_title(assigns) do
    ~H"""
    <p class={"leading-none font-semibold #{@class}"}>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_content(assigns) do
    ~H"""
    <div class={"px-6 #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_footer(assigns) do
    ~H"""
    <div class={"flex items-center px-6 #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :variant, :string, default: "default"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={badge_class(@variant, @class)}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp badge_class(variant, extra) do
    base =
      "inline-flex items-center justify-center rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap shrink-0"

    var_class =
      case variant do
        "outline" -> "border border-border text-foreground bg-transparent"
        "secondary" -> "bg-secondary text-secondary-foreground"
        "destructive" -> "bg-destructive text-white"
        "success" -> "border border-green-500/30 bg-green-500/15 text-green-500"
        "warning" -> "border border-orange-500/30 bg-orange-500/15 text-orange-500"
        _ -> "bg-primary text-primary-foreground"
      end

    "#{base} #{var_class} #{extra}"
  end

  attr :variant, :string, default: "default"
  attr :size, :string, default: "default"
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={button_class(@variant, @size, @class)}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_class(variant, size, extra) do
    base =
      "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all disabled:pointer-events-none disabled:opacity-50 cursor-pointer"

    var_class =
      case variant do
        "outline" ->
          "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground"

        "destructive" ->
          "bg-destructive text-white hover:bg-destructive/90"

        "ghost" ->
          "hover:bg-accent hover:text-accent-foreground"

        "secondary" ->
          "bg-secondary text-secondary-foreground hover:bg-secondary/80"

        _ ->
          "bg-primary text-primary-foreground hover:bg-primary/90"
      end

    size_class =
      case size do
        "sm" -> "h-8 rounded-md px-3 text-xs"
        "lg" -> "h-10 rounded-md px-6"
        "icon" -> "size-9"
        _ -> "h-9 px-4 py-2"
      end

    "#{base} #{var_class} #{size_class} #{extra}"
  end

  attr :orientation, :string, default: "horizontal"
  attr :class, :string, default: ""

  def separator(assigns) do
    ~H"""
    <div class={separator_class(@orientation, @class)} />
    """
  end

  defp separator_class("vertical", extra), do: "bg-border shrink-0 w-[1px] self-stretch #{extra}"
  defp separator_class(_, extra), do: "bg-border shrink-0 h-[1px] w-full #{extra}"

  attr :type, :string, default: "text"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(id name value placeholder min max step readonly disabled phx-debounce)

  def ui_input(assigns) do
    ~H"""
    <input
      type={@type}
      class={"border-input h-9 w-full min-w-0 rounded-md border bg-transparent px-3 py-1 text-sm transition-colors outline-none focus:border-ring focus:ring-1 focus:ring-ring/50 disabled:opacity-50 disabled:cursor-not-allowed placeholder:text-muted-foreground #{@class}"}
      {@rest}
    />
    """
  end
end
